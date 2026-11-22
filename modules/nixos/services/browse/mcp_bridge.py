#!/usr/bin/env python3
"""Authenticated Streamable HTTP MCP bridge for `browse mcp`.

Wraps the stdio-only `browse mcp` server behind a stateful Streamable HTTP
`/mcp` endpoint guarded by a constant-time Bearer token check. Designed to sit
on loopback behind Vesta's nginx so Executor (and Nebula clients) can reach
paired remote browsers without exposing unauthenticated endpoints.
"""

from __future__ import annotations

import asyncio
import contextlib
import hmac
import logging
import os
import secrets
import sys
from collections.abc import AsyncIterator, Awaitable, Callable
from pathlib import Path
from typing import Any

import anyio
import uvicorn
from mcp import MCPError, types
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client
from mcp.server.lowlevel.server import Server
from mcp.server.streamable_http_manager import StreamableHTTPSessionManager
from starlette.applications import Starlette
from starlette.middleware import Middleware
from starlette.responses import JSONResponse
from starlette.routing import BaseRoute, Route
from starlette.types import ASGIApp, Receive, Scope, Send

logger = logging.getLogger("browse-mcp")

HTTP_METHODS = ["DELETE", "GET", "HEAD", "OPTIONS", "POST"]
DEFAULT_SESSION_IDLE_TIMEOUT = 1800.0
DEFAULT_MAX_SESSIONS = 64
DEFAULT_MAX_REQUEST_BODY_SIZE = 16 * 1024 * 1024


def load_or_create_token(path: Path) -> str:
    """Return the Bearer token stored at `path`, generating a private one if absent."""
    path.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)

    if path.exists():
        existing = path.read_text(encoding="utf-8").strip()
        if existing:
            return existing

    token = secrets.token_urlsafe(32)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(f"{token}\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    except Exception:
        with contextlib.suppress(OSError):
            tmp.unlink()
        raise
    return token


def _extract_bearer(scope: Scope) -> str | None:
    for raw_name, raw_value in scope.get("headers", ()):
        if raw_name.lower() == b"authorization":
            value = raw_value.decode("latin-1").strip()
            scheme, _, credential = value.partition(" ")
            if scheme.lower() == "bearer":
                token = credential.strip()
                if token:
                    return token
            return None
    return None


class BearerAuthMiddleware:
    """Require `Authorization: Bearer <token>` on every HTTP request."""

    def __init__(self, app: ASGIApp, token: str) -> None:
        self._app = app
        self._token = token

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope.get("type") == "http":
            provided = _extract_bearer(scope)
            if provided is None or not hmac.compare_digest(provided, self._token):
                response = JSONResponse(
                    {"error": "Unauthorized"},
                    status_code=401,
                    headers={"WWW-Authenticate": "Bearer"},
                )
                await response(scope, receive, send)
                return
        await self._app(scope, receive, send)


def _is_disconnect(error: BaseException) -> bool:
    if isinstance(error, (anyio.ClosedResourceError, anyio.BrokenResourceError, EOFError)):
        return True
    return isinstance(error, MCPError) and error.code == types.CONNECTION_CLOSED


@contextlib.asynccontextmanager
async def watch_eof(
    raw_read_stream: Any,
    on_eof: Callable[[], None],
) -> AsyncIterator[Any]:
    """Forward `raw_read_stream` and invoke `on_eof` immediately if it closes while idle."""
    fwd_writer, fwd_reader = anyio.create_memory_object_stream(0)

    async def forward() -> None:
        try:
            async with fwd_writer:
                async for item in raw_read_stream:
                    await fwd_writer.send(item)
        except (anyio.BrokenResourceError, anyio.ClosedResourceError):
            return
        on_eof()

    async with anyio.create_task_group() as tg:
        tg.start_soon(forward)
        try:
            yield fwd_reader
        finally:
            tg.cancel_scope.cancel()
            await fwd_reader.aclose()


async def create_proxy_server(
    remote_app: ClientSession,
    *,
    on_disconnect: Callable[[], None] | None = None,
) -> Server[Any]:
    """Build an MCP Server forwarding tool discovery and calls to `remote_app`."""
    init = await remote_app.initialize()

    def _note_disconnect(error: BaseException) -> None:
        if _is_disconnect(error):
            logger.error("Upstream browse mcp stdio session closed: %s", error)
            if on_disconnect is not None:
                on_disconnect()

    on_list_tools = None
    on_call_tool = None
    if init.capabilities.tools:

        async def _list_tools(
            _ctx: Any,
            params: types.PaginatedRequestParams | None,
        ) -> types.ListToolsResult:
            try:
                return await remote_app.list_tools(params=params)
            except Exception as error:
                _note_disconnect(error)
                raise

        async def _call_tool(
            _ctx: Any,
            params: types.CallToolRequestParams,
        ) -> types.CallToolResult:
            try:
                return await remote_app.call_tool(
                    params.name,
                    params.arguments or {},
                    meta=params.meta,
                )
            except Exception as error:
                _note_disconnect(error)
                return types.CallToolResult(
                    content=[types.TextContent(type="text", text=str(error))],
                    is_error=True,
                )

        on_list_tools = _list_tools
        on_call_tool = _call_tool

    return Server(
        name=init.server_info.name,
        version=init.server_info.version,
        instructions=init.instructions,
        on_list_tools=on_list_tools,
        on_call_tool=on_call_tool,
    )


class _ASGIAdapter:
    def __init__(self, endpoint: Callable[[Scope, Receive, Send], Awaitable[None]]) -> None:
        self._endpoint = endpoint

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        await self._endpoint(scope, receive, send)


_INIT_SUCCEEDED_SCOPE_KEY = "_browse_mcp_init_succeeded"


async def _track_initialize(ctx: Any, call_next: Any) -> Any:
    result = await call_next(ctx)
    if ctx.method == "initialize" and not isinstance(result, types.ErrorData):
        request = getattr(ctx, "request", None)
        scope = getattr(request, "scope", None)
        if isinstance(scope, dict):
            flag = scope.get(_INIT_SUCCEEDED_SCOPE_KEY)
            if isinstance(flag, list):
                flag[0] = True
    return result


def create_app(
    mcp_server: Server[Any],
    token: str,
    *,
    session_idle_timeout: float = DEFAULT_SESSION_IDLE_TIMEOUT,
    max_sessions: int = DEFAULT_MAX_SESSIONS,
    max_request_body_size: int = DEFAULT_MAX_REQUEST_BODY_SIZE,
) -> tuple[Starlette, StreamableHTTPSessionManager]:
    """Create a Starlette app serving only authenticated Streamable HTTP at `/mcp`."""
    if _track_initialize not in mcp_server.middleware:
        mcp_server.middleware.append(_track_initialize)

    manager = StreamableHTTPSessionManager(
        app=mcp_server,
        event_store=None,
        json_response=True,
        stateless=False,
        session_idle_timeout=session_idle_timeout,
        max_sessions=max_sessions,
        max_request_body_size=max_request_body_size,
    )

    async def handle_mcp(scope: Scope, receive: Receive, send: Send) -> None:
        updated = scope
        opening_request = False
        if scope.get("type") == "http":
            opening_request = not any(
                name.lower() == b"mcp-session-id" for name, _ in scope.get("headers", ())
            )
            path = scope.get("path", "")
            if path and path.rstrip("/") == "/mcp" and not path.endswith("/"):
                updated = dict(scope)
                updated["path"] = path + "/"
                raw_path = scope.get("raw_path")
                if raw_path:
                    path_part, sep, query_part = raw_path.partition(b"?")
                    updated["raw_path"] = path_part.rstrip(b"/") + b"/" + sep + query_part

        if not opening_request:
            await manager.handle_request(updated, receive, send)
            return

        # Work around mcp 2.3.0 StreamableHTTPSessionManager._serve_opening_request
        # treating any HTTP status <400 as established, which keeps a session slot
        # when `initialize` fails validation with an HTTP 200 JSON-RPC error.
        # Remove once upstream `mcp` discards sessions whose opening handshake fails.
        init_succeeded = [False]
        updated = dict(updated)
        updated[_INIT_SUCCEEDED_SCOPE_KEY] = init_succeeded
        created_session_id: str | None = None
        response_status: int | None = None

        async def discard_if_uninitialized() -> None:
            if created_session_id is not None and not init_succeeded[0]:
                transport = manager._server_instances.get(created_session_id)
                if transport is not None:
                    await manager._discard_session(created_session_id, transport)

        async def inspect_send(message: Any) -> None:
            nonlocal created_session_id, response_status
            if message["type"] == "http.response.start":
                response_status = message["status"]
                for raw_name, raw_value in message.get("headers", ()):
                    if raw_name.lower() == b"mcp-session-id":
                        created_session_id = raw_value.decode("latin-1")
                        break
            elif (
                message["type"] == "http.response.body"
                and not message.get("more_body", False)
                and response_status is not None
                and response_status < 400
            ):
                await discard_if_uninitialized()
            await send(message)

        try:
            await manager.handle_request(updated, receive, inspect_send)
        finally:
            await discard_if_uninitialized()

    mcp_endpoint = _ASGIAdapter(handle_mcp)
    routes: list[BaseRoute] = [
        Route("/mcp", endpoint=mcp_endpoint, methods=HTTP_METHODS, include_in_schema=False),
        Route("/mcp/", endpoint=mcp_endpoint, methods=HTTP_METHODS, include_in_schema=False),
    ]
    app = Starlette(
        routes=routes,
        middleware=[Middleware(BearerAuthMiddleware, token=token)],
    )
    app.router.redirect_slashes = False
    return app, manager


async def serve(browse_bin: str, host: str, port: int, token_file: Path) -> None:
    token = load_or_create_token(token_file)
    params = StdioServerParameters(
        command=browse_bin,
        args=["mcp"],
        env=dict(os.environ),
    )

    http_server: uvicorn.Server | None = None
    shutdown_requested = False

    def request_exit() -> None:
        nonlocal shutdown_requested
        shutdown_requested = True
        if http_server is not None:
            http_server.should_exit = True

    def on_stdio_eof() -> None:
        logger.error("Upstream browse mcp stdio process exited while idle; shutting down")
        request_exit()

    async with stdio_client(params) as (raw_read_stream, write_stream):
        async with watch_eof(raw_read_stream, on_stdio_eof) as read_stream:
            async with ClientSession(read_stream, write_stream) as session:
                proxy = await create_proxy_server(session, on_disconnect=request_exit)
                if shutdown_requested:
                    return
                app, manager = create_app(proxy, token)
                async with manager.run():
                    if shutdown_requested:
                        return
                    config = uvicorn.Config(
                        app,
                        host=host,
                        port=port,
                        access_log=False,
                        log_level="warning",
                    )
                    http_server = uvicorn.Server(config)
                    if shutdown_requested:
                        return
                    logger.info("browse-mcp: listening on http://%s:%d/mcp", host, port)
                    await http_server.serve()


def main() -> None:
    logging.basicConfig(
        level=logging.WARNING,
        format="%(levelname)s %(message)s",
        stream=sys.stderr,
    )
    logger.setLevel(logging.INFO)
    browse_bin = os.environ["BROWSE_BIN"]
    host = os.environ.get("BROWSE_MCP_HOST", "127.0.0.1")
    port = int(os.environ.get("BROWSE_MCP_PORT", "19989"))
    token_file = Path(os.environ["BROWSE_MCP_TOKEN_FILE"])
    asyncio.run(serve(browse_bin, host, port, token_file))


if __name__ == "__main__":
    main()

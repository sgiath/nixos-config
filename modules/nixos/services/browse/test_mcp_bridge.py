import asyncio
import contextlib
import json
import os
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import anyio
import httpx
import uvicorn
from mcp import ClientSession, MCPError, types
from mcp.shared.message import SessionMessage

import mcp_bridge


class FakeSession:
    def __init__(
        self,
        *,
        tools=None,
        call_result=None,
        call_error=None,
        instructions="Browse plain instructions.",
    ):
        self._tools = tools if tools is not None else [
            types.Tool(
                name="status",
                description="Show relay and browser status.",
                input_schema={"type": "object", "properties": {}},
            ),
            types.Tool(
                name="screenshot",
                description="Take a screenshot.",
                input_schema={"type": "object", "properties": {"tab": {"type": "integer"}}},
            ),
        ]
        self._call_result = call_result
        self._call_error = call_error
        self._instructions = instructions
        self.calls = []

    async def initialize(self):
        return types.InitializeResult(
            protocol_version="2025-03-26",
            capabilities=types.ServerCapabilities(tools=types.ToolsCapability()),
            server_info=types.Implementation(name="browse", version="0.1.5"),
            instructions=self._instructions,
        )

    async def list_tools(self, params=None):
        return types.ListToolsResult(tools=self._tools)

    async def call_tool(self, name, arguments=None, **kwargs):
        self.calls.append((name, arguments))
        if self._call_error is not None:
            raise self._call_error
        return self._call_result


def _mcp_headers(token: str | None = None, session_id: str | None = None) -> dict[str, str]:
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    if session_id is not None:
        headers["Mcp-Session-Id"] = session_id
    return headers


class TokenTests(unittest.TestCase):
    def test_creates_private_token_and_reuses_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            token_path = Path(tmp) / "nested" / "mcp-token"
            first = mcp_bridge.load_or_create_token(token_path)
            self.assertGreaterEqual(len(first), 32)
            self.assertEqual(stat.S_IMODE(token_path.parent.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE(token_path.stat().st_mode), 0o600)
            second = mcp_bridge.load_or_create_token(token_path)
            self.assertEqual(first, second)


class BridgeTests(unittest.IsolatedAsyncioTestCase):
    @contextlib.asynccontextmanager
    async def _client_with_manager(
        self,
        session: FakeSession,
        token: str = "secret-token",
        on_disconnect=None,
        **app_kwargs,
    ):
        proxy = await mcp_bridge.create_proxy_server(session, on_disconnect=on_disconnect)
        app, manager = mcp_bridge.create_app(proxy, token, **app_kwargs)
        async with manager.run():
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
                yield client, manager

    @contextlib.asynccontextmanager
    async def _client(self, session: FakeSession, token: str = "secret-token", on_disconnect=None):
        async with self._client_with_manager(session, token=token, on_disconnect=on_disconnect) as (
            client,
            _manager,
        ):
            yield client

    async def test_rejects_missing_wrong_or_non_bearer_auth(self):
        session = FakeSession()
        payload = {"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}
        async with self._client(session, token="expected-secret") as client:
            r_missing = await client.post("/mcp", json=payload, headers=_mcp_headers())
            self.assertEqual(r_missing.status_code, 401)
            self.assertEqual(r_missing.headers.get("www-authenticate"), "Bearer")

            r_wrong = await client.post("/mcp", json=payload, headers=_mcp_headers("wrong-secret"))
            self.assertEqual(r_wrong.status_code, 401)

            basic_headers = _mcp_headers()
            basic_headers["Authorization"] = "Basic expected-secret"
            r_basic = await client.post("/mcp", json=payload, headers=basic_headers)
            self.assertEqual(r_basic.status_code, 401)

            # Non-/mcp paths are not leaked without auth, and 404 with auth.
            self.assertEqual((await client.get("/status")).status_code, 401)
            self.assertEqual((await client.get("/sse")).status_code, 401)
            self.assertEqual(
                (await client.get("/status", headers={"Authorization": "Bearer expected-secret"})).status_code,
                404,
            )
            self.assertEqual(
                (await client.get("/sse", headers={"Authorization": "Bearer expected-secret"})).status_code,
                404,
            )

    async def test_stateful_mcp_initialize_list_and_image_passthrough(self):
        image_result = types.CallToolResult(
            content=[
                types.ImageContent(type="image", data="iVBORw0KGgo=", mime_type="image/png"),
                types.TextContent(type="text", text='{"width":100,"height":50}'),
            ],
            is_error=False,
        )
        session = FakeSession(call_result=image_result)
        async with self._client(session, token="tok123") as client:
            # Case-insensitive Bearer scheme on /mcp (no trailing slash redirect).
            init_headers = _mcp_headers()
            init_headers["Authorization"] = "bearer tok123"
            r_init = await client.post(
                "/mcp",
                json={
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2025-03-26",
                        "capabilities": {},
                        "clientInfo": {"name": "executor", "version": "1.0"},
                    },
                },
                headers=init_headers,
            )
            self.assertEqual(r_init.status_code, 200)
            session_id = r_init.headers.get("mcp-session-id")
            self.assertTrue(session_id)
            init_body = r_init.json()["result"]
            self.assertEqual(init_body["serverInfo"]["name"], "browse")
            self.assertEqual(init_body["instructions"], "Browse plain instructions.")

            r_list = await client.post(
                "/mcp/",
                json={"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
                headers=_mcp_headers("tok123", session_id=session_id),
            )
            self.assertEqual(r_list.status_code, 200)
            tool_names = [t["name"] for t in r_list.json()["result"]["tools"]]
            self.assertEqual(tool_names, ["status", "screenshot"])

            r_call = await client.post(
                "/mcp",
                json={
                    "jsonrpc": "2.0",
                    "id": 3,
                    "method": "tools/call",
                    "params": {"name": "screenshot", "arguments": {"tab": 7}},
                },
                headers=_mcp_headers("tok123", session_id=session_id),
            )
            self.assertEqual(r_call.status_code, 200)
            result = r_call.json()["result"]
            self.assertFalse(result["isError"])
            self.assertEqual(result["content"][0]["type"], "image")
            self.assertEqual(result["content"][0]["data"], "iVBORw0KGgo=")
            self.assertEqual(result["content"][0]["mimeType"], "image/png")
            self.assertEqual(session.calls, [("screenshot", {"tab": 7})])

            r_del = await client.delete("/mcp", headers=_mcp_headers("tok123", session_id=session_id))
            self.assertEqual(r_del.status_code, 200)

    async def _init_session(self, client: httpx.AsyncClient, token: str) -> str:
        r = await client.post(
            "/mcp",
            json={
                "jsonrpc": "2.0",
                "id": 0,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2025-03-26",
                    "capabilities": {},
                    "clientInfo": {"name": "executor", "version": "1.0"},
                },
            },
            headers=_mcp_headers(token),
        )
        self.assertEqual(r.status_code, 200)
        session_id = r.headers.get("mcp-session-id")
        self.assertTrue(session_id)
        return session_id

    async def test_preserves_tool_errors_and_triggers_disconnect_on_closed_stdio(self):
        err_result = types.CallToolResult(
            content=[types.TextContent(type="text", text="No browser connected")],
            is_error=True,
        )
        session = FakeSession(call_result=err_result)
        async with self._client(session, token="tok") as client:
            sid = await self._init_session(client, "tok")
            r = await client.post(
                "/mcp",
                json={
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "tools/call",
                    "params": {"name": "status", "arguments": {}},
                },
                headers=_mcp_headers("tok", session_id=sid),
            )
            self.assertEqual(r.status_code, 200)
            self.assertTrue(r.json()["result"]["isError"])
            self.assertEqual(r.json()["result"]["content"][0]["text"], "No browser connected")

        disconnected = []
        broken = FakeSession(call_error=anyio.ClosedResourceError())
        async with self._client(broken, token="tok", on_disconnect=lambda: disconnected.append(True)) as client:
            sid = await self._init_session(client, "tok")
            r = await client.post(
                "/mcp",
                json={
                    "jsonrpc": "2.0",
                    "id": 2,
                    "method": "tools/call",
                    "params": {"name": "status", "arguments": {}},
                },
                headers=_mcp_headers("tok", session_id=sid),
            )
            self.assertEqual(r.status_code, 200)
            self.assertTrue(r.json()["result"]["isError"])
            self.assertEqual(disconnected, [True])

        disconnected_mcp = []
        broken_mcp = FakeSession(
            call_error=MCPError(code=types.CONNECTION_CLOSED, message="closed")
        )
        async with self._client(
            broken_mcp, token="tok", on_disconnect=lambda: disconnected_mcp.append(True)
        ) as client:
            sid = await self._init_session(client, "tok")
            await client.post(
                "/mcp",
                json={
                    "jsonrpc": "2.0",
                    "id": 3,
                    "method": "tools/call",
                    "params": {"name": "status", "arguments": {}},
                },
                headers=_mcp_headers("tok", session_id=sid),
            )
            self.assertEqual(disconnected_mcp, [True])

    async def test_forwards_cancellation_to_upstream_stdio_session(self):
        c2s_write, c2s_read = anyio.create_memory_object_stream(10)
        s2c_write, s2c_read = anyio.create_memory_object_stream(10)
        call_received = asyncio.Event()
        cancelled_ids: list[int | str] = []
        upstream_call_id: list[int | str] = []

        async def fake_stdio_server():
            async with c2s_read, s2c_write:
                async for item in c2s_read:
                    msg = item.message
                    if isinstance(msg, types.JSONRPCRequest):
                        if msg.method == "initialize":
                            reply = types.JSONRPCResponse(
                                jsonrpc="2.0",
                                id=msg.id,
                                result=types.InitializeResult(
                                    protocol_version="2025-03-26",
                                    capabilities=types.ServerCapabilities(tools=types.ToolsCapability()),
                                    server_info=types.Implementation(name="browse", version="0.1.5"),
                                    instructions="plain",
                                ).model_dump(by_alias=True, mode="json", exclude_none=True),
                            )
                            await s2c_write.send(SessionMessage(reply))
                        elif msg.method == "tools/call":
                            upstream_call_id.append(msg.id)
                            call_received.set()
                    elif isinstance(msg, types.JSONRPCNotification):
                        if msg.method == "notifications/cancelled":
                            cancelled_ids.append(msg.params["requestId"])

        async with anyio.create_task_group() as tg:
            tg.start_soon(fake_stdio_server)
            async with ClientSession(s2c_read, c2s_write) as session:
                proxy = await mcp_bridge.create_proxy_server(session)
                app, manager = mcp_bridge.create_app(proxy, "tok")
                async with manager.run():
                    transport = httpx.ASGITransport(app=app)
                    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
                        sid = await self._init_session(client, "tok")

                        call_task = asyncio.create_task(
                            client.post(
                                "/mcp",
                                json={
                                    "jsonrpc": "2.0",
                                    "id": 42,
                                    "method": "tools/call",
                                    "params": {"name": "handoff", "arguments": {}},
                                },
                                headers=_mcp_headers("tok", session_id=sid),
                            )
                        )
                        await asyncio.wait_for(call_received.wait(), timeout=2.0)

                        r_cancel = await client.post(
                            "/mcp",
                            json={
                                "jsonrpc": "2.0",
                                "method": "notifications/cancelled",
                                "params": {"requestId": 42, "reason": "user aborted"},
                            },
                            headers=_mcp_headers("tok", session_id=sid),
                        )
                        self.assertEqual(r_cancel.status_code, 202)

                        r_call = await asyncio.wait_for(call_task, timeout=2.0)
                        self.assertIn("error", r_call.json())
                        self.assertEqual(cancelled_ids, upstream_call_id)
            tg.cancel_scope.cancel()

    async def test_detects_idle_stdio_eof_immediately(self):
        raw_write, raw_read = anyio.create_memory_object_stream(1)
        eof_fired = asyncio.Event()

        async with raw_read:
            async with mcp_bridge.watch_eof(raw_read, eof_fired.set) as watched_read:
                self.assertFalse(eof_fired.is_set())
                await raw_write.aclose()
                await asyncio.wait_for(eof_fired.wait(), timeout=1.0)
                self.assertTrue(eof_fired.is_set())
                await watched_read.aclose()

    async def test_delete_removes_session_and_rejects_reuse(self):
        session = FakeSession()
        async with self._client_with_manager(session, token="tok") as (client, manager):
            sid = await self._init_session(client, "tok")
            self.assertIn(sid, manager._server_instances)

            r_del = await client.delete("/mcp", headers=_mcp_headers("tok", session_id=sid))
            self.assertEqual(r_del.status_code, 200)
            self.assertNotIn(sid, manager._server_instances)
            self.assertEqual(len(manager._server_instances), 0)

            r_after = await client.post(
                "/mcp",
                json={"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}},
                headers=_mcp_headers("tok", session_id=sid),
            )
            self.assertEqual(r_after.status_code, 404)

    async def test_rejected_opening_request_does_not_leak_session(self):
        session = FakeSession()
        async with self._client_with_manager(session, token="tok") as (client, manager):
            # Missing session ID with a non-initialize method must be rejected and leave no session behind.
            r_bad = await client.post(
                "/mcp",
                json={"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}},
                headers=_mcp_headers("tok"),
            )
            self.assertGreaterEqual(r_bad.status_code, 400)
            self.assertEqual(len(manager._server_instances), 0)

    async def test_client_disconnect_during_opening_upload_does_not_raise(self):
        session = FakeSession()
        proxy = await mcp_bridge.create_proxy_server(session)
        app, manager = mcp_bridge.create_app(proxy, "tok")
        async with manager.run():
            messages = iter(
                [
                    {"type": "http.request", "body": b"{", "more_body": True},
                    {"type": "http.disconnect"},
                ]
            )
            sent: list[dict] = []

            async def receive():
                return next(messages, {"type": "http.disconnect"})

            async def send(message):
                sent.append(message)

            scope = {
                "type": "http",
                "asgi": {"version": "3.0"},
                "http_version": "1.1",
                "method": "POST",
                "scheme": "http",
                "path": "/mcp",
                "raw_path": b"/mcp",
                "query_string": b"",
                "headers": [
                    (b"authorization", b"Bearer tok"),
                    (b"content-type", b"application/json"),
                    (b"accept", b"application/json, text/event-stream"),
                ],
            }
            await app(scope, receive, send)
            self.assertTrue(any(m["type"] == "http.response.start" and m["status"] >= 400 for m in sent))
            self.assertEqual(len(manager._server_instances), 0)

    async def test_failed_initialize_does_not_leak_session(self):
        session = FakeSession()
        async with self._client_with_manager(session, token="tok") as (client, manager):
            # Invalid initialize params return HTTP 200 with a JSON-RPC error, even when
            # the echoed string request ID is larger than a small inspection buffer.
            for req_id in (1, "x" * 100_000):
                r_bad_init = await client.post(
                    "/mcp",
                    json={"jsonrpc": "2.0", "id": req_id, "method": "initialize", "params": {}},
                    headers=_mcp_headers("tok"),
                )
                self.assertEqual(r_bad_init.status_code, 200)
                self.assertIn("error", r_bad_init.json())
                self.assertEqual(len(manager._server_instances), 0)

                sid = r_bad_init.headers.get("mcp-session-id")
                if sid is not None:
                    r_reuse = await client.post(
                        "/mcp",
                        json={"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
                        headers=_mcp_headers("tok", session_id=sid),
                    )
                    self.assertEqual(r_reuse.status_code, 404)

    async def test_max_sessions_enforces_limit_and_recovers_after_delete(self):
        session = FakeSession()
        async with self._client_with_manager(session, token="tok", max_sessions=2) as (client, manager):
            sid1 = await self._init_session(client, "tok")
            sid2 = await self._init_session(client, "tok")
            self.assertEqual(len(manager._server_instances), 2)

            r_full = await client.post(
                "/mcp",
                json={
                    "jsonrpc": "2.0",
                    "id": 99,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2025-03-26",
                        "capabilities": {},
                        "clientInfo": {"name": "executor", "version": "1.0"},
                    },
                },
                headers=_mcp_headers("tok"),
            )
            self.assertEqual(r_full.status_code, 503)
            self.assertEqual(len(manager._server_instances), 2)

            r_del = await client.delete("/mcp", headers=_mcp_headers("tok", session_id=sid1))
            self.assertEqual(r_del.status_code, 200)
            sid3 = await self._init_session(client, "tok")
            self.assertEqual(len(manager._server_instances), 2)
            self.assertNotEqual(sid3, sid2)

    async def test_idle_session_expires_and_is_reclaimed(self):
        session = FakeSession()
        async with self._client_with_manager(session, token="tok", session_idle_timeout=0.05) as (
            client,
            manager,
        ):
            sid = await self._init_session(client, "tok")
            self.assertIn(sid, manager._server_instances)

            deadline = asyncio.get_running_loop().time() + 2.0
            while sid in manager._server_instances and asyncio.get_running_loop().time() < deadline:
                await asyncio.sleep(0.02)

            self.assertNotIn(sid, manager._server_instances)
            r_expired = await client.post(
                "/mcp",
                json={"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}},
                headers=_mcp_headers("tok", session_id=sid),
            )
            self.assertEqual(r_expired.status_code, 404)

    async def test_serve_exits_when_stdio_eof_arrives_during_startup(self):
        with tempfile.TemporaryDirectory() as tmp:
            fixture = Path(tmp) / "fake-browse"
            fixture.write_text(
                f"#!{sys.executable}\n"
                "import json, sys\n"
                "line = sys.stdin.readline()\n"
                "req = json.loads(line)\n"
                "resp = {\n"
                "    'jsonrpc': '2.0',\n"
                "    'id': req['id'],\n"
                "    'result': {\n"
                "        'protocolVersion': '2025-03-26',\n"
                "        'capabilities': {'tools': {}},\n"
                "        'serverInfo': {'name': 'browse', 'version': '0.1.5'},\n"
                "    },\n"
                "}\n"
                "sys.stdout.write(json.dumps(resp) + '\\n')\n"
                "sys.stdout.flush()\n",
                encoding="utf-8",
            )
            fixture.chmod(0o700)
            token_file = Path(tmp) / "mcp-token"

            real_create_proxy = mcp_bridge.create_proxy_server
            served: list[bool] = []
            real_uvicorn_serve = uvicorn.Server.serve

            async def delayed_create_proxy(*args, **kwargs):
                proxy = await real_create_proxy(*args, **kwargs)
                # Ensure EOF from the exited fixture is processed before uvicorn.Server is created.
                await asyncio.sleep(0.1)
                return proxy

            async def tracked_uvicorn_serve(server_self, *args, **kwargs):
                served.append(True)
                return await real_uvicorn_serve(server_self, *args, **kwargs)

            with (
                mock.patch.object(mcp_bridge, "create_proxy_server", side_effect=delayed_create_proxy),
                mock.patch.object(uvicorn.Server, "serve", autospec=True, side_effect=tracked_uvicorn_serve),
            ):
                await asyncio.wait_for(
                    mcp_bridge.serve(str(fixture), "127.0.0.1", 0, token_file),
                    timeout=1.5,
                )

            self.assertEqual(served, [])


if __name__ == "__main__":
    unittest.main()

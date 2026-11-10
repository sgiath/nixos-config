"""T3 through its MCP endpoint.

Review threads run in full-access mode (nobody is there to approve their commands). A bearer from
`t3 auth session issue` is capped at approval-required, and T3 refuses to start, stop or settle a full-access
thread with it. So the client signs in the way T3's own environment links do: the owner CLI mints a one-time
pairing code (`t3 auth pairing create`), and the OAuth pairing-code decision exchanges it for a full-access MCP
bearer. The bearer lives only in this process's memory, is rotated every ROTATE and revoked on rotation and at exit;
sessions left by a crashed earlier run are revoked at startup by their client name.
"""

import base64
import hashlib
import json
import logging
import secrets
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import UTC, datetime
from pathlib import Path
from typing import Protocol

from . import limits
from .models import Selection, ThreadState
from .proc import CommandError, run, run_json

log = logging.getLogger("auto-review")

ACTIVE = {"idle", "preparing", "queued", "starting", "running", "waiting"}
PROTOCOL = "2025-06-18"
CLIENT = "auto-review"
REDIRECT = "http://127.0.0.1/auto-review"
SCOPES = ("orchestration:read", "orchestration:operate", "settings:write", "source-control:write")
ROTATE = 12 * 3600
RUNTIME = Path.home() / ".t3/userdata/server-runtime.json"


class T3Error(Exception):
    pass


class T3(Protocol):
    def launch(self, *, project: str, title: str, message: str, selection: Selection, client_request_id: str) -> dict:
        """Start a thread at the project's root checkout with this model selection and full access. The same
        `client_request_id` replays the first launch. Returns {"thread_id", "run_id", "url"}."""

    def read(self, thread_id: str) -> ThreadState: ...

    def send(self, thread_id: str, message: str) -> None: ...

    def stop(self, thread_id: str, reason: str) -> None: ...

    def settle(self, thread_id: str) -> None: ...

    def link(self, thread_id: str, url: str) -> None:
        """Attach the MR/PR at `url` to the thread; linking it again is a no-op."""

    def catalog(self) -> list[dict]:
        """README `GET /api/catalog` shape."""


class T3Client:
    def __init__(self, runtime: Path = RUNTIME):
        self._runtime = runtime
        self._lock = threading.RLock()
        self._token: str | None = None
        self._token_at = 0.0
        self._session_id: str | None = None  # T3 auth session of the bearer, for revocation
        self._mcp: str | None = None  # MCP transport session
        self._request = 0
        self._capabilities: dict | None = None
        self._cleaned = False

    # The T3 interface

    def launch(self, *, project: str, title: str, message: str, selection: Selection, client_request_id: str) -> dict:
        """T3 replays a `clientRequestId` only within one bearer session, and the bearer rotates; so the title also
        carries the request id, and a thread already carrying it is adopted instead of starting a second one."""
        tag = _title_tag(client_request_id)
        listed = self._call("t3_thread_list", {
            "projectId": project, "titleContains": tag, "includeSubagents": False, "limit": 100,
        })
        existing = [t for t in listed.get("threads", []) if t.get("title", "").endswith(tag)]
        if len(existing) > 1:
            raise T3Error(f"{len(existing)} threads carry {tag}; refusing to guess which one is this review")
        if existing:
            found = existing[0]
            return {"thread_id": found["threadId"], "run_id": found.get("latestRunId"), "url": found.get("link")}
        result = self._call("t3_thread_launch", {
            "projectId": project,
            "title": f"{title} {tag}",
            "message": message,
            "runtimeMode": "full-access",
            "modelSelection": {
                "instanceId": selection.provider,
                "model": selection.model,
                "options": [{"id": self._effort_option(selection.provider), "value": selection.effort}],
            },
            "workspaceStrategy": {"type": "root"},
            "clientRequestId": client_request_id,
        })
        return {"thread_id": result["threadId"], "run_id": result.get("runId"), "url": result.get("link")}

    def read(self, thread_id: str) -> ThreadState:
        thread = self._call("t3_thread_read", {"threadId": thread_id, "view": "messages", "limit": 1, "runLimit": 1})
        thread = thread.get("thread", thread)
        status = thread["status"]
        common = {"settled": bool(thread.get("settled")), "updated_at": thread.get("updatedAt")}
        if thread.get("pendingRequestCount"):
            return ThreadState("waiting_input", **common)
        if status in ACTIVE:
            return ThreadState("active", **common)
        if status == "completed":
            return ThreadState("completed", selection=self._selection(thread_id), **common)
        error = self._last_error(thread_id)
        if status == "failed" and (reset := limits.reset_time(error, datetime.now(UTC))):
            return ThreadState("limited", limit_reset=reset.strftime("%Y-%m-%dT%H:%M:%SZ"), error=error, **common)
        return ThreadState("failed", error=error or status, **common)

    def send(self, thread_id: str, message: str) -> None:
        self._call("t3_thread_send", {"threadId": thread_id, "message": message, "mode": "queue"})

    def stop(self, thread_id: str, reason: str) -> None:
        self._call("t3_thread_interrupt", {"threadId": thread_id, "stop": True, "reason": reason})

    def settle(self, thread_id: str) -> None:
        self._call("t3_thread_organize", {"threadId": thread_id, "action": "settle"})

    def link(self, thread_id: str, url: str) -> None:
        self._call("link_pull_request", {"threadId": thread_id, "url": url})

    def catalog(self) -> list[dict]:
        return [
            {
                "provider": provider["providerInstanceId"],
                "label": provider.get("displayName") or provider["providerInstanceId"],
                "models": [
                    {
                        "id": model["id"],
                        "label": model.get("label") or model["id"],
                        "efforts": next((o["values"] for o in model.get("options", []) if _is_effort(o["id"])), []),
                    }
                    for model in provider.get("models", [])
                ],
            }
            for provider in self._capabilities_now()["providers"]
            if provider.get("canRunChildTask") and provider.get("models")
        ]

    def close(self) -> None:
        with self._lock:
            self._revoke()

    # Thread details

    def _selection(self, thread_id: str) -> Selection | None:
        """What the thread actually ran on, from T3 rather than the agent's own account."""
        try:
            selected = self._call("t3_thread_configure", {"threadId": thread_id})["modelSelection"]
        except (T3Error, KeyError):
            return None
        effort = next((o["value"] for o in selected.get("options", []) if _is_effort(o["id"])), "default")
        return Selection(selected["instanceId"], selected["model"], str(effort))

    def _last_error(self, thread_id: str) -> str | None:
        """Activity is paged oldest first; the run's failure is its last `error` item."""
        error, after = None, None
        for _ in range(50):
            args = {"threadId": thread_id, "view": "activity", "limit": 100, "maxCharsPerItem": 2000}
            if after is not None:
                args["afterPosition"] = after
            page = self._call("t3_thread_read", args)
            for item in page.get("items", []):
                if item.get("type") == "error" and item.get("text"):
                    error = item["text"]
            if not page.get("hasMore"):
                break
            after = page.get("nextPosition")
        return error

    def _effort_option(self, provider: str) -> str:
        for instance in self._capabilities_now()["providers"]:
            if instance["providerInstanceId"] == provider:
                for model in instance.get("models", []):
                    for option in model.get("options", []):
                        if _is_effort(option["id"]):
                            return option["id"]
        return "effort"

    def _capabilities_now(self) -> dict:
        if self._capabilities is None:
            self._capabilities = self._call("orchestrator_capabilities", {})
        return self._capabilities

    # MCP transport

    def _call(self, tool: str, arguments: dict) -> dict:
        with self._lock:
            for attempt in range(2):
                self._ensure_session()
                try:
                    response = self._rpc("tools/call", {"name": tool, "arguments": arguments})
                except _Expired:
                    self._mcp = None
                    if attempt:
                        raise T3Error(f"{tool}: MCP session expired twice") from None
                    continue
                except _Unauthorized:
                    self._token = self._mcp = None
                    if attempt:
                        raise T3Error(f"{tool}: T3 refused the bearer") from None
                    continue
                return _tool_result(tool, response)
        raise AssertionError("unreachable")

    def _ensure_session(self) -> None:
        if self._token is None or time.monotonic() - self._token_at > ROTATE:
            self._revoke()
            self._mint()
        if self._mcp is None:
            self._mcp = ""
            init = self._rpc("initialize", {
                "protocolVersion": PROTOCOL, "capabilities": {}, "clientInfo": {"name": CLIENT, "version": "1"},
            })
            if "error" in init:
                raise T3Error(f"MCP initialize: {init['error']}")
            self._notify_initialized()

    def _rpc(self, method: str, params: dict) -> dict:
        self._request += 1
        body = {"jsonrpc": "2.0", "id": self._request, "method": method, "params": params}
        status, headers, text = self._http(body)
        if method == "initialize":
            self._mcp = headers.get("mcp-session-id") or ""
        return _decode(text)

    def _notify_initialized(self) -> None:
        self._http({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def _http(self, body: dict) -> tuple[int, dict, str]:
        headers = {
            "Authorization": f"Bearer {self._token}",
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "Mcp-Protocol-Version": PROTOCOL,
        }
        if self._mcp:
            headers["Mcp-Session-Id"] = self._mcp
        request = urllib.request.Request(self._origin() + "/mcp", data=json.dumps(body).encode(), headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return response.status, {k.lower(): v for k, v in response.headers.items()}, response.read().decode()
        except urllib.error.HTTPError as error:
            if error.code == 401:
                raise _Unauthorized() from None
            if error.code == 404 and self._mcp:
                raise _Expired() from None
            raise T3Error(f"T3 MCP answered HTTP {error.code}: {error.read()[:300]!r}") from None
        except OSError as error:
            raise T3Error(f"T3 MCP unreachable: {error}") from None

    def _origin(self) -> str:
        try:
            return json.loads(self._runtime.read_text())["origin"].rstrip("/")
        except (OSError, ValueError, KeyError) as error:
            raise T3Error(f"cannot read the T3 server address from {self._runtime}: {error}") from None

    # Bearer lifecycle

    def _mint(self) -> None:
        if not self._cleaned:
            self._revoke_leftovers()
            self._cleaned = True
        origin = self._origin()
        name = f"{CLIENT} {datetime.now(UTC):%Y-%m-%dT%H:%M:%SZ}"
        scopes = [arg for scope in SCOPES for arg in ("--scope", scope)]
        try:
            pairing = run_json(["t3", "auth", "pairing", "create", "--ttl", "5m", "--label", CLIENT, *scopes, "--json"],
                               timeout=60)
        except CommandError as error:
            raise T3Error(f"t3 auth pairing create: {error}") from None
        try:
            registered = _post_json(f"{origin}/oauth/mcp/register", {"client_name": name, "redirect_uris": [REDIRECT]})
            verifier = _b64(secrets.token_bytes(32))
            state = _b64(secrets.token_bytes(16))
            decided = _post_json(f"{origin}/oauth/mcp/decision", {
                "authorization": {
                    "response_type": "code", "client_id": registered["client_id"], "redirect_uri": REDIRECT,
                    "code_challenge": _b64(hashlib.sha256(verifier.encode()).digest()),
                    "code_challenge_method": "S256", "state": state, "resource": f"{origin}/mcp",
                },
                "decision": {"_tag": "pairing-code", "access": "full-access", "code": pairing["credential"]},
            })
            query = urllib.parse.parse_qs(urllib.parse.urlparse(decided["redirectTo"]).query)
            if query.get("state", [None])[0] != state or "code" not in query:
                raise T3Error(f"T3 did not approve the sign-in: {query.get('error_description', ['no code'])[0]}")
            token = _post_form(f"{origin}/oauth/mcp/token", {
                "grant_type": "authorization_code", "code": query["code"][0], "redirect_uri": REDIRECT,
                "client_id": registered["client_id"], "code_verifier": verifier, "resource": f"{origin}/mcp",
            })
        finally:
            try:
                run(["t3", "auth", "pairing", "revoke", pairing["id"]], timeout=60)
            except CommandError:
                pass  # a used pairing code is already gone
        self._token, self._token_at, self._mcp = token["access_token"], time.monotonic(), None
        self._session_id = next((s["sessionId"] for s in _sessions() if name in json.dumps(s.get("client"))), None)
        log.info("signed in to T3 at %s (full-access MCP session %s)", origin, self._session_id or "unknown")

    def _revoke(self) -> None:
        if self._session_id:
            try:
                run(["t3", "auth", "session", "revoke", self._session_id], timeout=60)
            except CommandError as error:
                log.warning("revoking T3 session %s failed: %s", self._session_id, error)
        self._token = self._session_id = self._mcp = None

    def _revoke_leftovers(self) -> None:
        for session in _sessions():
            if f'"{CLIENT} ' in json.dumps(session.get("client")):
                try:
                    run(["t3", "auth", "session", "revoke", session["sessionId"]], timeout=60)
                    log.info("revoked T3 session %s left by an earlier run", session["sessionId"])
                except CommandError as error:
                    log.warning("revoking leftover T3 session failed: %s", error)


class _Expired(Exception):
    pass


class _Unauthorized(Exception):
    pass


def _sessions() -> list[dict]:
    try:
        return run_json(["t3", "auth", "session", "list", "--json"], timeout=60)
    except CommandError as error:
        log.warning("listing T3 sessions failed: %s", error)
        return []


def _decode(text: str) -> dict:
    """One JSON object, or (should T3 switch) server-sent events whose last `data:` line holds it."""
    text = text.strip()
    if text.startswith("{"):
        return json.loads(text)
    data = [line[5:].strip() for line in text.splitlines() if line.startswith("data:")]
    if not data:
        raise T3Error(f"unexpected MCP response: {text[:200]!r}")
    return json.loads(data[-1])


def _tool_result(tool: str, response: dict) -> dict:
    if "error" in response:
        raise T3Error(f"{tool}: {response['error'].get('message', response['error'])}")
    result = response["result"]
    if result.get("isError"):
        text = (result.get("content") or [{}])[0].get("text", "")
        try:
            failure = json.loads(text)
            text = f"{failure.get('code')}: {failure.get('message')}"
        except ValueError:
            pass
        raise T3Error(f"{tool}: {text}")
    if "structuredContent" in result:
        return result["structuredContent"]
    return json.loads((result.get("content") or [{}])[0].get("text") or "{}")


def _post_json(url: str, payload: dict) -> dict:
    return _post(url, json.dumps(payload).encode(), "application/json")


def _post_form(url: str, payload: dict) -> dict:
    return _post(url, urllib.parse.urlencode(payload).encode(), "application/x-www-form-urlencoded")


def _post(url: str, data: bytes, kind: str) -> dict:
    request = urllib.request.Request(url, data=data, headers={"Content-Type": kind, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        raise T3Error(f"POST {urllib.parse.urlparse(url).path}: HTTP {error.code} {error.read()[:300]!r}") from None
    except OSError as error:
        raise T3Error(f"POST {urllib.parse.urlparse(url).path}: {error}") from None


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _title_tag(client_request_id: str) -> str:
    """`auto-review:3f9a01bc:42:1` -> `(review 3f9a01bc.42.1)`."""
    _, instance, review_id, attempt = client_request_id.split(":")
    return f"(review {instance}.{review_id}.{attempt})"


def _is_effort(option_id: str) -> bool:
    """Claude and fx call it `effort`, Codex `reasoningEffort`, OpenCode `variant`, Pi `thinking`."""
    return option_id in ("effort", "reasoningEffort", "variant", "thinking")

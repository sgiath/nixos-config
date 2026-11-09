"""The local web UI and its JSON API (README "HTTP API"), plus the worker thread that runs every write.

HTTP handlers only read the store and settings. Anything that calls GitLab, GitHub or T3 is queued for the worker,
so one thread decides and writes, in order.
"""

import json
import logging
import mimetypes
import queue
import re
import threading
from datetime import UTC, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from . import note, settings as settings_mod
from .engine import ActionError, Engine
from .settings import SettingsError, SettingsFile
from .store import ACTIVE, Store

log = logging.getLogger("auto-review")
UI = Path(__file__).parent / "ui"
SAMPLE = {
    "reviewer": "filip.vavera1", "provider": "codex", "model": "gpt-6.1-sol",
    "effort": "high", "harness": "Codex harness", "repo": "remote-com/neo-payroll/neo",
    "number": "7627", "head_sha": "8a036c0ca011fe041c6a8b4d6d111f69c78710f7", "head_short": "8a036c0c",
    "finding_id": "SR-1", "title": "Retry re-sends the whole batch", "frequency": "3", "severity": "4",
    "score": "12", "threshold": "5", "disposition": "open",
}


class Worker:
    """Runs `engine.tick` every poll interval and the queued UI actions in between."""

    def __init__(self, engine: Engine, settings: SettingsFile):
        self.engine = engine
        self.settings = settings
        self.actions: queue.Queue = queue.Queue()
        self.stopping = threading.Event()
        self.poll_now = threading.Event()
        self.running = False
        self.next_at: datetime | None = None

    def submit(self, name: str, *args) -> None:
        self.actions.put((name, args))
        self.poll_now.set()

    def run(self) -> None:
        while not self.stopping.is_set():
            self._actions()
            self.running = True
            try:
                self.engine.tick()
            except Exception:  # noqa: BLE001 - a crashed tick must not stop the service; it is logged and retried
                log.exception("poll failed")
            finally:
                self.running = False
            self._actions()
            interval = self.settings.get()["poll_interval_seconds"]
            self.next_at = datetime.fromtimestamp(datetime.now(UTC).timestamp() + interval, UTC)
            self.poll_now.wait(interval)
            self.poll_now.clear()

    def _actions(self) -> None:
        while True:
            try:
                name, args = self.actions.get_nowait()
            except queue.Empty:
                return
            if name == "poll":
                continue
            try:
                getattr(self.engine, name)(*args)
            except ActionError as error:
                self.engine.record("warn", f"{name} refused: {error}", review_id=_review_id(args))
            except Exception as error:  # noqa: BLE001 - an action failure is shown in the UI, not fatal
                log.exception("%s failed", name)
                self.engine.record("error", f"{name} failed: {error}", review_id=_review_id(args))


class App:
    def __init__(self, engine: Engine, store: Store, settings: SettingsFile, t3, port: int):
        self.engine, self.store, self.settings, self.t3, self.port = engine, store, settings, t3, port
        self.worker = Worker(engine, settings)
        self._catalog: tuple[float, list] | None = None

    def serve(self) -> None:
        thread = threading.Thread(target=self.worker.run, name="worker", daemon=True)
        thread.start()
        server = ThreadingHTTPServer(("127.0.0.1", self.port), _handler(self))
        server.daemon_threads = True
        log.info("serving on http://127.0.0.1:%d", self.port)
        try:
            server.serve_forever()
        finally:
            self.worker.stopping.set()
            self.worker.poll_now.set()
            server.server_close()

    # GET

    def status(self) -> dict:
        settings = self.settings.get()
        now = self.engine.now()
        counts = {s: len(self.store.in_status(s)) for s in ("queued", "running", "limited", "failed")}
        running = len(self.store.in_status("launching", "running", "limited", "deciding", "posting"))
        quiet_active, quiet_until = self.engine.quiet(now)
        return {
            "now": _iso(now),
            "paused": settings["paused"],
            "dry_run": settings["dry_run"],
            "poll": {
                "last_at": self.engine.last_poll_at,
                "next_at": _iso(self.worker.next_at) if self.worker.next_at else None,
                "last_error": self.engine.last_poll_error,
                "running": self.worker.running,
            },
            "identities": dict(self.engine.identities),
            "limits": [
                {"provider": provider, **limit} for provider, limit in self.store.limits(_iso(now)).items()
            ],
            "quiet": {
                "enabled": settings["quiet_hours"]["enabled"],
                "active": quiet_active,
                "until": _iso(quiet_until) if quiet_until else None,
            },
            "budget": {
                "running": running,
                "max_concurrent": settings["max_concurrent"],
                "launched_today": self.engine.launched_today(now),
                "max_launches_per_day": settings["max_launches_per_day"],
            },
            "counts": {**counts, "waiting": len(self.engine.waiting())},
        }

    def settings_view(self) -> dict:
        return {
            "effective": self.settings.get(),
            "defaults": settings_mod.effective(self.settings.defaults(), {}),
            "overrides": self.settings.overrides(),
        }

    def catalog(self) -> list:
        now = datetime.now(UTC).timestamp()
        if self._catalog is None or now - self._catalog[0] > 600:
            self._catalog = (now, self.t3.catalog())
        return self._catalog[1]

    def reviews(self, query: dict) -> list[dict]:
        view = query.get("view", "active")
        if view not in ("active", "history", "failed"):
            raise BadRequest("view must be active, history or failed")
        before = int(query["before"]) if query.get("before") else None
        limit = min(int(query.get("limit", 50)), 200)
        rows = self.store.list(view, repo=query.get("repo"), limit=limit, before=before)
        return [self.engine.summary(row) for row in rows]

    def review(self, review_id: int) -> dict:
        row = self.store.get(review_id)
        if row is None:
            raise NotFound(f"no review {review_id}")
        return self.engine.detail(row)

    # Actions

    def action(self, review_id: int, name: str, finding_id: str | None = None) -> None:
        row = self.store.get(review_id)
        if row is None:
            raise NotFound(f"no review {review_id}")
        if name == "cancel" and row["status"] not in ACTIVE:
            raise Conflict(f"review is {row['status']}")
        if name == "retry" and row["status"] not in ("failed", "cancelled", "done"):
            raise Conflict(f"review is {row['status']}")
        if name == "post_anyway":
            if row["status"] != "done":
                raise Conflict(f"review is {row['status']}")
            states = {f["finding_id"]: f["state"] for f in self.store.findings(review_id, row["attempt"])}
            if states.get(finding_id) not in ("below", "would_post", "not_posted"):
                raise Conflict(f"finding {finding_id} is {states.get(finding_id, 'unknown')}")
            self.worker.submit(name, review_id, finding_id)
            return
        self.worker.submit(name, review_id)

    def threads(self) -> list[dict]:
        """Threads waiting for Filip's decision, newest judgment first."""
        result = []
        for t in self.store.disputed():
            reviews = self.store.for_mr(t["repo"], t["number"])
            latest = reviews[-1] if reviews else {}
            result.append({
                **{k: t[k] for k in ("repo", "number", "marker", "review_id", "finding_id", "title", "score",
                                     "comment_url", "reasoning", "proposed_reply", "updated_at")},
                "mr_url": latest.get("url"), "mr_title": latest.get("title"),
            })
        return sorted(result, key=lambda t: t["updated_at"] or "", reverse=True)

    def thread_action(self, name: str, body: dict) -> None:
        key = (str(body["repo"]), int(body["number"]), str(body["marker"]))
        item = self.store.thread(*key)
        if item is None:
            raise NotFound("no such thread")
        if item["status"] != "disputed":
            raise Conflict(f"thread is {item['status']}")
        if name != "dismiss" and self.settings.get()["paused"]:
            raise Conflict("paused")
        text = str(body.get("text") or "").strip()
        if name == "reply" and not text:
            raise BadRequest("the reply is empty")
        if name == "accept":
            self.worker.submit("accept_thread", key, text or None)
        elif name == "reply":
            self.worker.submit("reply_thread", key, text)
        else:
            self.worker.submit("dismiss_thread", key)


def _review_id(args: tuple) -> int | None:
    return args[0] if args and isinstance(args[0], int) else None


class BadRequest(Exception):
    status = 400


class NotFound(Exception):
    status = 404


class Conflict(Exception):
    status = 409


REVIEW_ACTION = re.compile(r"^/api/reviews/(\d+)/(cancel|retry)$")
FINDING_POST = re.compile(r"^/api/reviews/(\d+)/findings/([A-Za-z0-9-]+)/post$")
REVIEW = re.compile(r"^/api/reviews/(\d+)$")
THREAD_ACTION = re.compile(r"^/api/threads/(accept|reply|dismiss)$")


def _handler(app: App):
    allowed_hosts = {f"127.0.0.1:{app.port}", f"localhost:{app.port}"}

    class Handler(BaseHTTPRequestHandler):
        server_version = "auto-review"

        def log_message(self, format, *args):  # noqa: A002 - routine requests stay out of the journal
            return

        def do_GET(self):
            self._dispatch(self._get)

        def do_POST(self):
            self._dispatch(self._post, mutating=True)

        def do_PATCH(self):
            self._dispatch(self._patch, mutating=True)

        def _dispatch(self, method, mutating: bool = False):
            if self.headers.get("Host") not in allowed_hosts:
                return self._send(403, {"error": "unexpected Host"})
            origin = self.headers.get("Origin")
            if origin and origin.removeprefix("http://") not in allowed_hosts:
                return self._send(403, {"error": "cross-origin request"})
            if mutating and not (self.headers.get("Content-Type") or "").startswith("application/json"):
                return self._send(403, {"error": "Content-Type must be application/json"})
            url = urlparse(self.path)
            try:
                status, body = method(url.path, {k: v[-1] for k, v in parse_qs(url.query).items()})
            except SettingsError as error:
                return self._send(400, {"error": error.message, "field": error.field})
            except (BadRequest, NotFound, Conflict) as error:
                return self._send(error.status, {"error": str(error)})
            except (ValueError, KeyError) as error:
                return self._send(400, {"error": f"bad request: {error}"})
            except Exception as error:  # noqa: BLE001 - report to the UI, keep serving
                log.exception("%s %s failed", self.command, self.path)
                return self._send(500, {"error": str(error)})
            if isinstance(body, bytes):
                return self._send_file(status, body, url.path)
            return self._send(status, body)

        def _get(self, path: str, query: dict):
            if path == "/api/status":
                return 200, app.status()
            if path == "/api/settings":
                return 200, app.settings_view()
            if path == "/api/catalog":
                return 200, app.catalog()
            if path == "/api/reviews":
                return 200, app.reviews(query)
            if match := REVIEW.match(path):
                return 200, app.review(int(match.group(1)))
            if path == "/api/threads":
                return 200, app.threads()
            if path == "/api/waiting":
                return 200, app.engine.waiting()
            if path == "/api/discovered":
                return 200, app.engine.discovered()
            if path == "/api/events":
                return 200, app.store.events(limit=min(int(query.get("limit", 100)), 500))
            if path.startswith("/api/"):
                raise NotFound(path)
            return 200, _static(path)

        def _post(self, path: str, query: dict):
            body = self._body()
            if path == "/api/poll":
                app.worker.submit("poll")
                return 202, {"accepted": True}
            if path == "/api/note-preview":
                rendered, unknown = note.render(str(body.get("template", "")), SAMPLE)
                return 200, {"markdown": rendered, "unknown": unknown}
            if match := REVIEW_ACTION.match(path):
                app.action(int(match.group(1)), match.group(2))
                return 202, {"accepted": True}
            if match := THREAD_ACTION.match(path):
                app.thread_action(match.group(1), body)
                return 202, {"accepted": True}
            if match := FINDING_POST.match(path):
                app.action(int(match.group(1)), "post_anyway", match.group(2))
                return 202, {"accepted": True}
            raise NotFound(path)

        def _patch(self, path: str, query: dict):
            if path != "/api/settings":
                raise NotFound(path)
            body = self._body()
            if not isinstance(body, dict):
                raise BadRequest("body must be a JSON object")
            app.settings.patch(body)
            app.worker.submit("poll")
            return 200, app.settings_view()

        def _body(self):
            length = int(self.headers.get("Content-Length") or 0)
            if not length:
                return {}
            try:
                return json.loads(self.rfile.read(length))
            except ValueError as error:
                raise BadRequest(f"body is not JSON: {error}") from error

        def _send(self, status: int, body) -> None:
            data = json.dumps(body).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)

        def _send_file(self, status: int, data: bytes, path: str) -> None:
            kind = mimetypes.guess_type(path if path != "/" else "index.html")[0] or "application/octet-stream"
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Content-Security-Policy", "default-src 'self'; img-src 'self' data:")
            self.end_headers()
            self.wfile.write(data)

    return Handler


def _static(path: str) -> bytes:
    relative = "index.html" if path in ("", "/") else path.lstrip("/")
    target = (UI / relative).resolve()
    if UI.resolve() not in target.parents or not target.is_file():
        raise NotFound(path)
    return target.read_bytes()


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")

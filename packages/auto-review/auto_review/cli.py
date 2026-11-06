"""auto-review: review the MRs and PRs that request your review, in T3 threads, with a local web UI."""

import argparse
import fcntl
import html
import json
import logging
import os
import re
import signal
import subprocess
import sys
import urllib.request
from datetime import UTC, datetime
from pathlib import Path

from . import checkout
from .engine import Engine
from .forge.github import GitHub
from .forge.gitlab import GitLab
from .server import App
from .settings import SettingsFile
from .store import Store
from .t3 import T3Client

log = logging.getLogger("auto-review")

LEGACY_PROJECTS = {
    "neo": "remote-com/neo-payroll/neo",
    "tiger": "remote-com/employ-starbase/tiger",
    "labs": "remote-com/workbench/remote-vibed-labs",
}
LEGACY_OUTCOMES = {"approve": "clean", "block": "findings", "needs-filip": "needs_attention", "failed": None}
BRIEF_BASE = re.compile(r"diff base `([0-9a-f]{40})`")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="auto-review", description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    serve = commands.add_parser("serve", help="run the poller and the web UI")
    serve.add_argument("--defaults", type=Path, required=True, help="settings defaults (JSON, from Nix)")
    serve.add_argument("--port", type=int, default=8787)
    legacy = commands.add_parser("import-legacy", help="import the Spain poller's reviewed heads as done reviews")
    legacy.add_argument("directory", type=Path)
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s", stream=sys.stdout)

    state = state_dir()
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = open(state / "lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print(f"auto-review: another auto-review holds {state / 'lock'}", file=sys.stderr)
        return 1
    store = Store(state / "state.db")
    if args.command == "import-legacy":
        return import_legacy(store, args.directory)
    return _serve(store, state, args)


def state_dir() -> Path:
    if directory := os.environ.get("STATE_DIRECTORY"):
        return Path(directory.split(":")[0])
    return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "auto-review"


def _serve(store: Store, state: Path, args) -> int:
    settings = SettingsFile(args.defaults, state / "overrides.json")
    t3 = T3Client()
    engine = Engine(
        store, settings.get, {"gitlab": GitLab(), "github": GitHub()}, t3, checkout.fetch, state / "runs",
        Notifier(settings.get), lambda: datetime.now(UTC),
    )
    current = settings.get()
    mode = "paused" if current["paused"] else "dry run" if current["dry_run"] else "live"
    enabled = [repo_id for repo_id, repo in current["repos"].items() if repo["enabled"]]
    log.info("started (%s): watching %s", mode, ", ".join(enabled) or "no repos")
    signal.signal(signal.SIGTERM, _interrupt)
    try:
        App(engine, store, settings, t3, args.port).serve()
    except KeyboardInterrupt:
        log.info("stopping")
    finally:
        t3.close()
    return 0


def _interrupt(*_) -> None:
    raise KeyboardInterrupt


class Notifier:
    """Desktop notification and, when set, an ntfy topic. Failures to notify are logged, never raised."""

    def __init__(self, settings):
        self.settings = settings

    def __call__(self, title: str, body: str) -> None:
        notify = self.settings()["notify"]
        if notify["desktop"]:
            try:
                subprocess.run(
                    ["busctl", "--user", "call", "--", "org.freedesktop.Notifications",
                     "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "Notify", "susssasa{sv}i",
                     "auto-review", "0", "", title, html.escape(body[:500], quote=False), "0", "0", "-1"],
                    capture_output=True, timeout=10,
                )
            except (OSError, subprocess.TimeoutExpired) as error:
                log.warning("desktop notification failed: %s", error)
        if notify["ntfy_url"]:
            request = urllib.request.Request(notify["ntfy_url"], data=body[:2000].encode(), method="POST",
                                             headers={"Title": title.encode("ascii", "replace").decode()})
            try:
                urllib.request.urlopen(request, timeout=30).close()
            except OSError as error:
                log.warning("ntfy notification failed: %s", error)


def import_legacy(store: Store, directory: Path) -> int:
    """Each finished review of the old poller becomes a finished review here, so its head is never reviewed again.
    Reviews still in flight are not imported: stop the old timer only when none is left."""
    data = json.loads((directory / "state.json").read_text())
    imported = skipped = 0
    in_flight = []
    for record in data["reviews"].values():
        if record["status"] not in ("done", "failed"):
            in_flight.append(f"{record['project']}!{record['iid']}")
            continue
        path = LEGACY_PROJECTS[record["project"]]
        row = {
            "repo": f"gitlab:{path}", "forge": "gitlab", "path": path, "number": record["iid"],
            "head_sha": record["sha"], "base_sha": _legacy_base(record), "target": record["target"],
            "attempt": 1, "status": record["status"], "outcome": LEGACY_OUTCOMES.get(record.get("outcome")),
            "title": record.get("title"), "url": record.get("web_url"), "author": None,
            "provider": "claudeAgent_claude_remote", "model": "claude-opus-5-5",
            "effort": record.get("effort") or "xhigh", "contract": "spain-review/v1",
            "thread_id": record.get("thread_id"), "thread_url": record.get("thread_link"),
            "run_id": record.get("run_id"), "queued_at": record.get("launched_at"),
            "started_at": record.get("launched_at"), "finished_at": record.get("finished_at"),
            "error": record.get("action"), "summary": f"Imported from the Spain poller: {record.get('action', '')}",
            "active_seconds": _seconds_between(record.get("launched_at"), record.get("finished_at")),
            "approved": bool(record.get("approved")), "settled": True, "source": "legacy",
            "dry_run": record.get("mode") != "live",
        }
        if store.import_legacy(row):
            imported += 1
        else:
            skipped += 1
    print(json.dumps({"imported": imported, "already_present": skipped, "in_flight_not_imported": in_flight}))
    return 1 if in_flight else 0


def _seconds_between(start: str | None, end: str | None) -> int:
    if not start or not end:
        return 0
    delta = datetime.fromisoformat(end.replace("Z", "+00:00")) - datetime.fromisoformat(start.replace("Z", "+00:00"))
    return max(0, int(delta.total_seconds()))


def _legacy_base(record: dict) -> str:
    """The base the review saw: its own brief names it. The run directory is shared by a retargeted head's
    reviews, so its mr.json may hold the later base; the target column keeps those keys apart anyway."""
    run_dir = Path(record.get("run_dir") or "")
    brief = run_dir / "brief.md"
    if brief.exists() and (match := BRIEF_BASE.search(brief.read_text())):
        return match.group(1)
    mr = run_dir / "mr/mr.json"
    if mr.exists():
        return json.loads(mr.read_text())["diff_refs"]["base_sha"]
    return ""

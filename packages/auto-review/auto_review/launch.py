"""Launching queued reviews: re-read the change, fetch it, write the run directory and start the T3 thread."""

from datetime import UTC, datetime
from pathlib import Path

from . import bundle
from .checkout import CheckoutError, HeadMoved
from .models import Change, Selection
from .rules import eligibility, moved
from .settings import repo_view
from .store import BUSY
from .t3 import T3Error
from .threads import write as write_threads

LAUNCH_ATTEMPTS = 3


class Launcher:
    def __init__(self, engine):
        self.engine = engine
        self.failures: dict[int, int] = {}  # review id -> consecutive failed launches

    def launch_due(self, settings: dict) -> None:
        engine = self.engine
        now = engine.now()
        if settings["paused"] or engine.quiet(now)[0]:
            return
        running = len(engine.store.in_status(*BUSY))
        cap = settings["max_launches_per_day"]
        launched = engine.launched_today(now)
        limits = engine.store.limits(_iso(now))
        for row in engine.store.in_status("queued"):
            if running >= settings["max_concurrent"] or (cap is not None and launched >= cap):
                return
            if row["provider"] in limits or row["repo"] not in settings["repos"]:
                continue
            repo = repo_view(settings, row["repo"])
            if not repo["enabled"]:
                continue
            if any(other["status"] in BUSY for other in engine.store.for_mr(row["repo"], row["number"])):
                continue  # one review of an MR at a time, whatever its kind
            started = engine._guard(row["id"], lambda r=row: self.launch(r, settings, repo))
            if started:
                running += 1
                launched += 1

    def relaunch(self, row: dict, settings: dict) -> None:
        """A launch interrupted before its thread id was saved: the same client request id replays it."""
        engine = self.engine
        if row["repo"] not in settings["repos"]:
            return engine.fail(row, "repo is no longer watched")
        self.launch(row, settings, repo_view(settings, row["repo"]))

    def launch(self, row: dict, settings: dict, repo: dict) -> bool:
        engine = self.engine
        forge = engine.forges[row["forge"]]
        me = engine.me(row["forge"])
        change = forge.change(row["path"], row["number"], me)
        follow_up = row["kind"] == "follow_up"  # judges sgiath's own threads, so the review request does not matter
        if reason := moved(row, change) or (None if follow_up else _skip(change, repo, me)):
            if row["status"] == "launching":
                engine.fail(row, f"before launch: {reason}")
            else:
                engine.finish(row, "cancelled", error=f"before launch: {reason}")
                engine.record("info", f"cancelled before launch: {reason}", review_id=row["id"])
            return False
        if not follow_up and eligibility(change, repo["rules"], me).action == "wait":
            return False
        if engine.settings()["paused"] or engine.quiet(engine.now())[0]:
            return False  # paused from the UI while this tick read the forge
        now = _iso(engine.now())
        engine.store.update(row["id"], status="launching")
        engine.store.record_launch(row["id"], row["attempt"], now)
        try:
            engine.fetch(Path(repo["checkout"]), row["forge"], change)
        except HeadMoved as error:
            engine.finish(row, "superseded", error=str(error))
            engine.record("info", f"head moved while fetching: {error}", review_id=row["id"])
            return False
        except CheckoutError as error:
            engine.fail(row, f"checkout: {error}")
            return False
        run_dir = engine.run_dir(row)
        # A retried launch may adopt a thread T3 already started on the first bundle: keep what that agent read.
        if not (run_dir / "mr/own_threads.json").exists():
            threads = forge.threads(row["path"], row["number"])
            own, settled = engine.threads.snapshot(row, threads, me)
            if follow_up and not own:
                engine.finish(row, "cancelled", error="before launch: no open thread left to judge")
                engine.record("info", "cancelled before launch: no open thread left to judge", review_id=row["id"])
                return False
            bundle.write(run_dir, change, forge.diffs(row["path"], change), threads)
            write_threads(run_dir, own, settled)
        message = bundle.brief(row=row, repo=repo, change=change, run_dir=run_dir, me=me, threshold=repo["threshold"])
        title = (f"{'Follow-up' if follow_up else 'Review'} {bundle.ref(row['forge'], row['path'], row['number'])}"
                 f" @{row['head_sha'][:8]}")
        try:
            launched = engine.t3.launch(
                project=repo["t3_project"], title=title + (" (dry run)" if settings["dry_run"] else ""),
                message=message, selection=Selection(row["provider"], row["model"], row["effort"]),
                client_request_id=engine.request_id(row),
            )
        except T3Error as error:
            failures = self.failures.get(row["id"], 0) + 1
            self.failures[row["id"]] = failures
            if failures >= LAUNCH_ATTEMPTS:
                engine.fail(row, f"launch failed {failures} times: {error}")
            else:
                engine.record("warn", f"launch failed, will retry: {error}", review_id=row["id"])
            return False
        self.failures.pop(row["id"], None)
        engine.store.update(
            row["id"], status="running", thread_id=launched["thread_id"], run_id=launched.get("run_id"),
            thread_url=launched.get("url"), started_at=now, running_since=now, title=change.title,
            dry_run=settings["dry_run"],
        )
        engine.record("info", f"launched {row['model']}/{row['effort']} thread {launched['thread_id']}", review_id=row["id"])
        engine._link(row, launched["thread_id"])
        return True


def _skip(change: Change, repo: dict, me: str) -> str | None:
    verdict = eligibility(change, repo["rules"], me)
    return verdict.reason if verdict.action == "skip" else None


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")

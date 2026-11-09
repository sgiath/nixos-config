"""The worker: one `tick` advances running reviews, discovers new ones and launches what may start.

Dependencies are passed in so tests can replace each boundary:

- `settings()` returns the effective settings (settings.effective).
- `forges` maps `gitlab`/`github` to a forge.base.Forge.
- `t3` is a t3.T3.
- `fetch(checkout, forge_name, change)` fetches the change's head into the checkout; raises
  checkout.CheckoutError, or checkout.HeadMoved when the forge's head is not `change.head_sha`.
- `runs` is the directory of per-attempt run directories.
- `notify(title, body)` announces failures and needs-attention reviews.
- `now()` returns an aware UTC datetime.
"""

import logging
from collections.abc import Callable, Mapping
from datetime import UTC, datetime, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from . import bundle
from .checkout import CheckoutError, HeadMoved
from .forge.base import ForgeError
from .models import Change, Selection
from .publish import Publisher
from .rules import eligibility, moved
from .settings import CONTRACT, repo_view
from .store import ACTIVE, Store
from .t3 import T3Error
from .threads import Threads
from .threads import write as write_threads

log = logging.getLogger("auto-review")

BUSY = ("launching", "running", "limited", "deciding", "posting")
STALL = timedelta(minutes=10)
UNKNOWN_RESET = timedelta(minutes=30)
LAUNCH_ATTEMPTS = 3
IDENTITY_TTL = timedelta(hours=1)
DISCOVERY_EVERY = timedelta(minutes=10)
CONTINUE = "Continue where you left off. The usage limit that stopped this review has reset."


class ActionError(Exception):
    """A UI action that cannot run in the review's current state (HTTP 409)."""


class Engine:
    def __init__(
        self,
        store: Store,
        settings: Callable[[], dict],
        forges: Mapping[str, object],
        t3: object,
        fetch: Callable,
        runs: Path,
        notify: Callable[[str, str], None],
        now: Callable[[], datetime],
    ):
        self.store, self.settings, self.forges, self.t3 = store, settings, forges, t3
        self.fetch, self.runs, self.notify, self.now = fetch, Path(runs), notify, now
        self.identities: dict[str, str] = {}
        self.last_poll_at: str | None = None
        self.last_poll_error: str | None = None
        self._identity_at: dict[str, datetime] = {}
        self._waiting: list[dict] = []
        self._discovered: list[dict] = []
        self._discovered_at: datetime | None = None
        self._launch_failures: dict[int, int] = {}
        self._settle_warned: set[int] = set()
        self._linked: set[str] = set()  # threads this process attached their MR/PR to
        self.publisher = Publisher(self)
        self.threads = Threads(self)

    # The poll

    def tick(self) -> None:
        """One poll, in this order:

        1. Advance every review in `launching`, `running`, `limited`, `deciding`, `posting`.
        2. Settle finished reviews still waiting for it (auto_settle on, `done`/`superseded`, `settled` false).
        3. Discover: per enabled repo, list candidates, read each change, apply rules.eligibility; claim
           `review` ones (Store.claim dedups by key) and supersede active reviews of other keys of the same MR
           (stopping their threads); remember `wait`/`skip` ones for `waiting()`.
        4. Launch queued reviews, oldest first, while: not paused, not in quiet hours, fewer than
           `max_concurrent` running (launching, running, limited, deciding, posting count), under
           `max_launches_per_day`, and the review's provider has no unexpired limit. Before launching, re-read the
           change: a review whose MR closed, moved head/base or became ineligible is cancelled with that reason.

        4b. Before launching: per MR with an open or disputed thread of Filip's, queue a `follow_up` for new
           replies (threads.Threads.scan).

        Errors are contained per repo and per review; each is recorded as an event and the tick goes on.
        """
        settings = self.settings()
        self.last_poll_error = None
        for row in self.store.in_status(*BUSY):
            self._guard(row["id"], lambda r=row: self._advance(r, settings))
        if settings["auto_settle"]:
            self._settle_pending()
        self._discover(settings)
        self.threads.scan(settings)
        self._launch_due(settings)
        self.last_poll_at = _iso(self.now())

    def waiting(self) -> list[dict]:
        """MRs from the last discovery that were not claimed: {"repo", "number", "title", "url", "author", "reason"}."""
        return list(self._waiting)

    def discovered(self) -> list[dict]:
        return list(self._discovered)

    # Actions

    def cancel(self, review_id: int) -> None:
        """Queued -> cancelled; launching/running/limited -> stop the thread, cancelled. Else ActionError."""
        row = self._row(review_id)
        if row["status"] not in ("queued", "launching", "running", "limited"):
            raise ActionError(f"review is {row['status']}")
        if row["thread_id"]:
            self.t3.stop(row["thread_id"], "Cancelled from the auto-review UI")
        self._finish(row, "cancelled", error="cancelled from the UI")
        self.record("info", "cancelled", review_id=review_id)

    def retry(self, review_id: int) -> None:
        """A failed, cancelled or done review gets a new attempt: attempt + 1, `queued`, thread and error cleared.
        Else ActionError."""
        row = self._row(review_id)
        if row["status"] not in ("failed", "cancelled", "done"):
            raise ActionError(f"review is {row['status']}")
        selection = row["provider"], row["model"], row["effort"]
        if row["repo"] in self.settings()["repos"]:
            reviewer = repo_view(self.settings(), row["repo"])["reviewer"]
            selection = reviewer["provider"], reviewer["model"], reviewer["effort"]
        self.store.update(
            review_id, attempt=row["attempt"] + 1, status="queued", outcome=None, thread_id=None, thread_url=None,
            run_id=None, error=None, started_at=None, running_since=None, active_seconds=0, finished_at=None,
            limited_until=None, summary=None, not_reviewed=[], injection_attempts=[], dry_run=False,
            approved=False, settled=False, queued_at=_iso(self.now()),
            provider=selection[0], model=selection[1], effort=selection[2],
        )
        self._launch_failures.pop(review_id, None)
        self.record("info", f"retry queued as attempt {row['attempt'] + 1}", review_id=review_id)

    def post_anyway(self, review_id: int, finding_id: str) -> None:
        """Post one `below` or `would_post` finding of a done review now, ignoring dry run but not pause. Refused
        (ActionError) when the review is not done, the finding is in another state or has no anchor, or the MR's
        head or base moved."""
        self.publisher.post_anyway(self._row(review_id), finding_id)

    def accept_thread(self, key: tuple, reply: str | None) -> None:
        """Accept the author's answer on a disputed thread: optional reply, resolve, then reconsider approval."""
        self.threads.accept(key, reply)

    def reply_thread(self, key: tuple, body: str) -> None:
        """Post Filip's reply on a disputed thread; it stays open."""
        self.threads.reply(key, body)

    def dismiss_thread(self, key: tuple) -> None:
        """Keep a disputed thread open without writing anything."""
        self.threads.dismiss(key)

    # Status for the UI

    def record(self, level: str, message: str, *, review_id: int | None = None) -> None:
        self.store.event(level, message, review_id=review_id, now=_iso(self.now()))
        getattr(log, {"warn": "warning"}.get(level, level))("%s%s", f"review {review_id}: " if review_id else "", message)

    def quiet(self, now: datetime) -> tuple[bool, datetime | None]:
        """Whether quiet hours hold at `now`, and when they end."""
        settings = self.settings()
        quiet = settings["quiet_hours"]
        if not quiet["enabled"] or quiet["start"] == quiet["end"]:
            return False, None
        zone = ZoneInfo(settings["timezone"])
        local = now.astimezone(zone)
        start, end = _clock(quiet["start"]), _clock(quiet["end"])
        current = local.time().replace(second=0, microsecond=0)
        inside = start <= current < end if start < end else (current >= start or current < end)
        if not inside:
            return False, None
        until = datetime.combine(local.date(), end, zone)
        if until <= local:
            until += timedelta(days=1)
        return True, until.astimezone(UTC)

    def launched_today(self, now: datetime) -> int:
        zone = ZoneInfo(self.settings()["timezone"])
        midnight = datetime.combine(now.astimezone(zone).date(), time(0), zone)
        return self.store.launches_since(_iso(midnight))

    def summary(self, row: dict) -> dict:
        findings = self.store.findings(row["id"], row["attempt"])
        counts = {"posted": 0, "would_post": 0, "below": 0, "already_open": 0, "already_resolved": 0, "settled": 0,
                  "unanchored": 0, "not_posted": 0}
        for finding in findings:
            if finding["state"] in counts:
                counts[finding["state"]] += 1
        return {
            **{k: row[k] for k in (
                "id", "attempt", "repo", "forge", "number", "title", "url", "author", "head_sha", "base_sha",
                "target", "status", "outcome", "thread_url", "dry_run", "queued_at", "started_at", "finished_at",
                "limited_until", "error", "approved", "settled", "kind",
            )},
            "reviewer": {"provider": row["provider"], "model": row["model"], "effort": row["effort"]},
            "elapsed_seconds": self._elapsed(row),
            "counts": counts,
        }

    def detail(self, row: dict) -> dict:
        return {
            **self.summary(row),
            "summary": row["summary"],
            "not_reviewed": row["not_reviewed"],
            "injection_attempts": row["injection_attempts"],
            "findings": [
                {k: f[k] for k in ("finding_id", "title", "frequency", "severity", "score", "file", "line", "side",
                                   "state", "url", "body", "reasoning")}
                for f in self.store.findings(row["id"], row["attempt"])
            ],
            "events": self.store.events(review_id=row["id"], limit=200),
        }

    # Internals shared with publish.Publisher

    def me(self, forge_name: str) -> str:
        now = self.now()
        cached = self._identity_at.get(forge_name)
        if forge_name not in self.identities or cached is None or now - cached > IDENTITY_TTL:
            self.identities[forge_name] = self.forges[forge_name].whoami()
            self._identity_at[forge_name] = now
        return self.identities[forge_name]

    def request_id(self, row: dict) -> str:
        """Names one launch: this database's instance, the review and the attempt."""
        return f"auto-review:{self.store.instance_id()}:{row['id']}:{row['attempt']}"

    def run_dir(self, row: dict) -> Path:
        return self.runs / f"{row['id']}-{row['attempt']}"

    def fail(self, row: dict, reason: str) -> None:
        self._finish(row, "failed", error=reason)
        self.record("error", f"failed: {reason}", review_id=row["id"])
        self.notify(f"Review failed: {_ref(row)}", reason)

    def finish(self, row: dict, status: str, **fields) -> None:
        self._finish(row, status, **fields)

    # Advancing a review

    def _advance(self, row: dict, settings: dict) -> None:
        if row["thread_id"] and row["thread_id"] not in self._linked:
            self._link(row, row["thread_id"])
        status = row["status"]
        if status == "launching":
            return self._relaunch(row, settings)
        if status in ("deciding", "posting"):
            return self.publisher.publish(row, settings)
        state = self.t3.read(row["thread_id"])
        now = self.now()
        if status == "limited":
            if state.status == "active":
                return self._running(row, "resumed by T3")
            if state.status == "completed":
                return self._completed(row, settings, state)
            if row["limited_until"] and _iso(now) >= row["limited_until"]:
                self.t3.send(row["thread_id"], CONTINUE)
                return self._running(row, "usage limit reset; sent continue")
            return None
        if state.status in ("active", "waiting_input"):
            active = row["active_seconds"] + _seconds(row["running_since"], now)
            if active > settings["review_timeout_minutes"] * 60:
                self._stop(row, "review timed out")
                return self.fail(row, f"still running after {settings['review_timeout_minutes']} minutes")
            if state.status == "waiting_input" and state.updated_at and _parse(state.updated_at) < now - STALL:
                self._stop(row, "waiting on an approval nobody gives")
                return self.fail(row, "the thread is waiting on an approval prompt nobody answers")
            return None
        if state.status == "limited":
            until = state.limit_reset or _iso(now + UNKNOWN_RESET)
            clock = self._paused_clock(row, now, stopped_at=state.updated_at)
            self.store.update(row["id"], status="limited", limited_until=until, **clock)
            self.store.set_limit(row["provider"], until, state.error or "usage limit")
            self.record("warn", f"stopped by a usage limit of {row['provider']} until {until}", review_id=row["id"])
            return None
        if state.status == "completed":
            return self._completed(row, settings, state)
        return self.fail(row, f"thread ended: {state.error or state.status}")

    def _completed(self, row: dict, settings: dict, state) -> None:
        """The thread finished; T3's record of the model it ran on replaces the one requested."""
        fields = {"status": "deciding", **self._paused_clock(row, self.now())}
        if state.selection:
            fields.update(provider=state.selection.provider, model=state.selection.model, effort=state.selection.effort)
        self.store.update(row["id"], **fields)
        self.publisher.publish(self.store.get(row["id"]), settings)

    def _running(self, row: dict, message: str) -> None:
        self.store.update(row["id"], status="running", running_since=_iso(self.now()), limited_until=None)
        self.record("info", message, review_id=row["id"])

    def _paused_clock(self, row: dict, now: datetime, stopped_at: str | None = None) -> dict:
        """Stop the active-time clock. `stopped_at` (T3's last update of the thread) counts when it falls inside the
        running interval, so time the worker was down after a limit hit is not counted as running."""
        if not row["running_since"]:
            return {}
        end = now
        if stopped_at and _parse(row["running_since"]) <= _parse(stopped_at) < now:
            end = _parse(stopped_at)
        return {"active_seconds": row["active_seconds"] + _seconds(row["running_since"], end), "running_since": None}

    def _settle_pending(self) -> None:
        for row in self.store.in_status("done", "superseded"):
            if row["settled"] or not row["thread_id"]:
                continue
            try:
                self.t3.settle(row["thread_id"])
            except T3Error as error:
                if row["id"] not in self._settle_warned:
                    self._settle_warned.add(row["id"])
                    self.record("warn", f"settling the thread failed, retrying: {error}", review_id=row["id"])
                continue
            self._settle_warned.discard(row["id"])
            self.store.update(row["id"], settled=True)

    # Discovery

    def _discover(self, settings: dict) -> None:
        waiting = []
        for repo_id, repo in settings["repos"].items():
            if not repo["enabled"]:
                continue
            try:
                waiting += self._discover_repo(settings, repo_id, repo)
            except (ForgeError, T3Error, OSError) as error:
                self.last_poll_error = f"{repo_id}: {error}"
                self.record("warn", f"discovery in {repo_id} failed: {error}")
        self._waiting = waiting
        now = self.now()
        if self._discovered_at is None or now - self._discovered_at > DISCOVERY_EVERY:
            self._discovered_at = now
            self._discovered = self._discover_unwatched(settings)

    def _discover_repo(self, settings: dict, repo_id: str, repo: dict) -> list[dict]:
        forge = self.forges[repo["forge"]]
        me = self.me(repo["forge"])
        waiting = []
        for number in forge.candidates(repo["path"], me, repo["rules"]["include_authors"]):
            change = forge.change(repo["path"], number, me)
            verdict = eligibility(change, repo["rules"], me)
            if verdict.action != "review":
                waiting.append({"repo": repo_id, "number": number, "title": change.title, "url": change.url,
                                "author": change.author, "reason": verdict.reason})
                continue
            reviewer = repo_view(settings, repo_id)["reviewer"]
            review_id = self.store.claim(
                change, forge=repo["forge"], path=repo["path"], selection=Selection(**reviewer),
                contract=CONTRACT, now=_iso(self.now()),
            )
            if review_id:
                self.record("info", f"queued {_ref_change(change)} @{change.head_sha[:8]}", review_id=review_id)
            for other in self.store.for_mr(repo_id, number):
                if other["status"] in ACTIVE and _key(other) != change.key:
                    self._supersede(other, f"superseded by @{change.head_sha[:8]}")
        return waiting

    def _discover_unwatched(self, settings: dict) -> list[dict]:
        watched = set(settings["repos"])
        found = []
        for name in {repo["forge"] for repo in settings["repos"].values()}:
            try:
                for item in self.forges[name].discovered(self.me(name)):
                    if f"{item['forge']}:{item['path']}" not in watched:
                        found.append(item)
            except ForgeError as error:
                self.record("warn", f"listing review requests on {name} failed: {error}")
        return found

    def _supersede(self, row: dict, reason: str) -> None:
        if row["thread_id"] and row["status"] in ("launching", "running", "limited"):
            self._stop(row, reason)
        self._finish(row, "superseded", error=reason)
        self.record("info", reason, review_id=row["id"])

    # Launching

    def _launch_due(self, settings: dict) -> None:
        now = self.now()
        if settings["paused"] or self.quiet(now)[0]:
            return
        running = len(self.store.in_status(*BUSY))
        cap = settings["max_launches_per_day"]
        launched = self.launched_today(now)
        limits = self.store.limits(_iso(now))
        for row in self.store.in_status("queued"):
            if running >= settings["max_concurrent"] or (cap is not None and launched >= cap):
                return
            if row["provider"] in limits or row["repo"] not in settings["repos"]:
                continue
            repo = repo_view(settings, row["repo"])
            if not repo["enabled"]:
                continue
            started = self._guard(row["id"], lambda r=row: self._launch(r, settings, repo))
            if started:
                running += 1
                launched += 1

    def _relaunch(self, row: dict, settings: dict) -> None:
        """A launch interrupted before its thread id was saved: the same client request id replays it."""
        if row["repo"] not in settings["repos"]:
            return self.fail(row, "repo is no longer watched")
        self._launch(row, settings, repo_view(settings, row["repo"]))

    def _launch(self, row: dict, settings: dict, repo: dict) -> bool:
        forge = self.forges[row["forge"]]
        me = self.me(row["forge"])
        change = forge.change(row["path"], row["number"], me)
        follow_up = row["kind"] == "follow_up"  # judges Filip's own threads, so the review request does not matter
        if reason := moved(row, change) or (None if follow_up else _skip(change, repo, me)):
            if row["status"] == "launching":
                self.fail(row, f"before launch: {reason}")
            else:
                self._finish(row, "cancelled", error=f"before launch: {reason}")
                self.record("info", f"cancelled before launch: {reason}", review_id=row["id"])
            return False
        if not follow_up and eligibility(change, repo["rules"], me).action == "wait":
            return False
        if self.settings()["paused"] or self.quiet(self.now())[0]:
            return False  # paused from the UI while this tick read the forge
        now = _iso(self.now())
        self.store.update(row["id"], status="launching")
        self.store.record_launch(row["id"], row["attempt"], now)
        try:
            self.fetch(Path(repo["checkout"]), row["forge"], change)
        except HeadMoved as error:
            self._finish(row, "superseded", error=str(error))
            self.record("info", f"head moved while fetching: {error}", review_id=row["id"])
            return False
        except CheckoutError as error:
            self.fail(row, f"checkout: {error}")
            return False
        run_dir = self.run_dir(row)
        threads = forge.threads(row["path"], row["number"])
        own, settled = self.threads.snapshot(row, threads, me)
        if follow_up and not own:
            self._finish(row, "cancelled", error="before launch: no open thread left to judge")
            self.record("info", "cancelled before launch: no open thread left to judge", review_id=row["id"])
            return False
        bundle.write(run_dir, change, forge.diffs(row["path"], change), threads)
        write_threads(run_dir, own, settled)
        message = bundle.brief(row=row, repo=repo, change=change, run_dir=run_dir, me=me, threshold=repo["threshold"])
        title = (f"{'Follow-up' if follow_up else 'Review'} {bundle.ref(row['forge'], row['path'], row['number'])}"
                 f" @{row['head_sha'][:8]}")
        try:
            launched = self.t3.launch(
                project=repo["t3_project"], title=title + (" (dry run)" if settings["dry_run"] else ""),
                message=message, selection=Selection(row["provider"], row["model"], row["effort"]),
                client_request_id=self.request_id(row),
            )
        except T3Error as error:
            failures = self._launch_failures.get(row["id"], 0) + 1
            self._launch_failures[row["id"]] = failures
            if failures >= LAUNCH_ATTEMPTS:
                self.fail(row, f"launch failed {failures} times: {error}")
            else:
                self.record("warn", f"launch failed, will retry: {error}", review_id=row["id"])
            return False
        self._launch_failures.pop(row["id"], None)
        self.store.update(
            row["id"], status="running", thread_id=launched["thread_id"], run_id=launched.get("run_id"),
            thread_url=launched.get("url"), started_at=now, running_since=now, title=change.title,
            dry_run=settings["dry_run"],
        )
        self.record("info", f"launched {row['model']}/{row['effort']} thread {launched['thread_id']}", review_id=row["id"])
        self._link(row, launched["thread_id"])
        return True

    # Helpers

    def _row(self, review_id: int) -> dict:
        row = self.store.get(review_id)
        if row is None:
            raise ActionError(f"no review {review_id}")
        return row

    def _link(self, row: dict, thread_id: str) -> None:
        """Attach the MR/PR to its review thread, so the thread links straight to it. Idempotent in T3; a failure
        only warns and is retried on the next tick."""
        try:
            self.t3.link(thread_id, row["url"])
        except T3Error as error:
            self.record("warn", f"linking the MR to its thread failed, will retry: {error}", review_id=row["id"])
            return
        self._linked.add(thread_id)

    def _stop(self, row: dict, reason: str) -> None:
        try:
            self.t3.stop(row["thread_id"], reason)
        except T3Error as error:
            self.record("warn", f"stopping the thread failed: {error}", review_id=row["id"])

    def _finish(self, row: dict, status: str, **fields) -> None:
        clock = self._paused_clock(row, self.now()) if row["status"] == "running" else {}
        self.store.update(row["id"], status=status, finished_at=_iso(self.now()), **clock, **fields)

    def _guard(self, review_id: int, action):
        try:
            return action()
        except (ForgeError, T3Error, OSError, ValueError, KeyError) as error:
            self.last_poll_error = str(error)
            self.record("warn", f"{type(error).__name__}: {error}", review_id=review_id)
            return None

    def _elapsed(self, row: dict) -> int:
        now = self.now()
        if row["status"] == "queued":
            return _seconds(row["queued_at"], now)
        return row["active_seconds"] + _seconds(row["running_since"], now)



def _key(row: dict) -> tuple:
    return (row["repo"], row["number"], row["head_sha"], row["base_sha"], row["target"])


def _skip(change: Change, repo: dict, me: str) -> str | None:
    verdict = eligibility(change, repo["rules"], me)
    return verdict.reason if verdict.action == "skip" else None


def _ref(row: dict) -> str:
    return bundle.ref(row["forge"], row["path"], row["number"])


def _ref_change(change: Change) -> str:
    forge, _, path = change.repo.partition(":")
    return bundle.ref(forge, path, change.number)


def _clock(value: str) -> time:
    hour, minute = value.split(":")
    return time(int(hour), int(minute))


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def _parse(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _seconds(since: str | None, now: datetime) -> int:
    return max(0, int((now - _parse(since)).total_seconds())) if since else 0

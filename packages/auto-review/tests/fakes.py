"""Boundary fakes; no subprocesses, network, git or real T3 calls.

Forge.add/change supply current forge evidence. T3.complete writes an attempt-bound
verdict on the next read, just as a completing agent would. All effects share an
ordered journal so tests can prove posting precedes settlement.
"""

import json
from copy import deepcopy
from dataclasses import asdict, replace
from datetime import datetime, timedelta, timezone
from pathlib import Path

from auto_review.forge.base import ForgeError
from auto_review.models import Change, FileDiff, Finding, Note, Posted, Selection, Thread, ThreadState
from auto_review.settings import GLOBAL_DEFAULTS, REPO_DEFAULTS
from auto_review.t3 import T3Error

HEAD = "a" * 40
BASE = "b" * 40
REPO = "gitlab:team/service"
SELECTION = Selection("provider-a", "review-model", "high")
NOW = "2026-11-05T12:00:00Z"
PATCH = "@@ -10,3 +10,4 @@\n keep\n-old\n+new\n+added\n tail\n"
DIFFS = [FileDiff("src/old.py", "src/new.py", PATCH)]


def change(**fields):
    # Forge states are native: GitLab reports opened, GitHub reports open.
    if fields.get("repo", REPO).startswith("github:"):
        fields.setdefault("state", "open")
    return replace(Change(
        repo=REPO, number=7, title="Fix calculation", url="https://forge.invalid/7",
        author="alice", state="opened", draft=False, labels=("backend",),
        head_sha=HEAD, base_sha=BASE, target="main", pipeline="success",
        reviewers=("sgiath",), review_requested=True,
        diff_refs={"base_sha": BASE, "start_sha": BASE, "head_sha": HEAD},
    ), **fields)


def finding(**fields):
    return replace(Finding(
        id="SR-1", title="Incorrect calculation", frequency=1, severity=5,
        file="src/new.py", side="new", line=11, body="Use the current value.",
        reasoning="The old value persists.",
    ), **fields)


def raw_verdict(review_id=1, attempt=1, head_sha=HEAD, base_sha=BASE, **fields):
    return {
        "schema": "auto-review/v1", "review_id": review_id, "attempt": attempt,
        "head_sha": head_sha, "base_sha": base_sha, "status": "complete",
        "error": None, "summary": "Review complete", "findings": [],
        "not_reviewed": [], "injection_attempts": [], **fields,
    }


def raw_finding(**fields):
    return asdict(finding(**fields))


def configuration(checkout, **fields):
    """Already-effective settings, independent of the settings implementation."""
    result = deepcopy(GLOBAL_DEFAULTS)
    repo = deepcopy(REPO_DEFAULTS)
    repo.update(forge="gitlab", path="team/service", checkout=str(checkout), t3_project="project-a")
    result.update(reviewer=asdict(SELECTION), repos={REPO: repo})
    result.update(fields)
    return result


class Clock:
    def __init__(self):
        self.value = datetime(2026, 11, 5, 12, tzinfo=timezone.utc)

    def __call__(self):
        return self.value

    def advance(self, **duration):
        self.value += timedelta(**duration)

    def iso(self):
        return self.value.isoformat().replace("+00:00", "Z")


class Forge:
    def __init__(self, journal, name="gitlab", me="sgiath"):
        self.name, self.me, self.journal = name, me, journal
        self.changes = {}
        self.discussions = {}
        self.file_diffs = {}
        self.posts, self.post_attempts, self.approvals, self.marked = [], [], [], []
        self.fail_after = None  # Persist this many comments, then lose the response once.

    def add(self, item):
        self.changes[(item.repo.split(":", 1)[1], item.number)] = item
        return item

    def whoami(self):
        return self.me

    def candidates(self, path, me, include_authors):
        self.journal.append(("candidates", self.name, path))
        included = {a.casefold() for a in include_authors}
        return [n for (p, n), c in sorted(self.changes.items()) if p == path and c.state in ("open", "opened")
                and (c.review_requested or c.author.casefold() in included)]

    def change(self, path, number, me):
        self.journal.append(("change", self.name, path, number))
        return self.changes[(path, number)]

    def diffs(self, path, change):
        return self.file_diffs.get((path, change.number), list(DIFFS))

    def threads(self, path, number):
        self.journal.append(("threads", self.name, path, number))
        return list(self.discussions.get((path, number), []))

    def post(self, path, change, comments):
        self.post_attempts.append((path, change, list(comments)))
        self.journal.append(("post", self.name, tuple(c.finding_id for c in comments)))
        receipts = []
        fail_after, self.fail_after = self.fail_after, None
        for comment in comments:
            if fail_after is not None and len(receipts) >= fail_after:
                raise ForgeError("response lost while posting")
            remote_id = f"note-{len(self.posts) + 1}"
            self.posts.append(comment)
            self.discussions.setdefault((path, change.number), []).append(Thread(
                id=remote_id, resolved=False,
                notes=(Note(self.me, comment.body, remote_id),),
                path=comment.anchor.new_path if comment.anchor else None,
                line=comment.anchor.line if comment.anchor else None,
            ))
            receipts.append(Posted(comment.finding_id, remote_id, f"https://forge.invalid/#{remote_id}"))
        if fail_after is not None:
            raise ForgeError("response lost after posting")
        return receipts

    def mark_reviewed(self, path, change):
        self.marked.append((path, change))
        self.journal.append(("mark_reviewed", self.name, change.number))

    def approve(self, path, change):
        self.approvals.append((path, change))
        self.journal.append(("approve", self.name, change.head_sha))

    def discovered(self, me):
        return []


class T3:
    def __init__(self, runs, journal):
        self.runs, self.journal = Path(runs), journal
        self.launches, self.reads, self.sends, self.stops, self.settles = [], [], [], [], []
        self.launch_results, self.states, self.pending_verdicts = {}, {}, {}
        self.settle_failures = 0
        self.links = []
        self.link_failures = 0

    def launch(self, *, project, title, message, selection, client_request_id):
        self.launches.append(dict(project=project, title=title, message=message,
                                  selection=selection, client_request_id=client_request_id))
        self.journal.append(("launch", client_request_id))
        if client_request_id not in self.launch_results:
            thread_id = f"thread-{len(self.launch_results) + 1}"
            self.launch_results[client_request_id] = dict(
                thread_id=thread_id, run_id=f"run-{thread_id}", url=f"t3-thread://{thread_id}")
            self.states[thread_id] = ThreadState("active", selection=selection)
        return dict(self.launch_results[client_request_id])

    def complete(self, review, **verdict_fields):
        thread_id = review["thread_id"]
        self.pending_verdicts[thread_id] = (review["id"], review["attempt"], raw_verdict(
            review["id"], review["attempt"], review["head_sha"], review["base_sha"], **verdict_fields))
        self.states[thread_id] = ThreadState("completed")

    def read(self, thread_id):
        self.reads.append(thread_id)
        self.journal.append(("read", thread_id))
        if thread_id in self.pending_verdicts:
            review_id, attempt, payload = self.pending_verdicts.pop(thread_id)
            directory = self.runs / f"{review_id}-{attempt}"
            directory.mkdir(parents=True, exist_ok=True)
            (directory / "verdict.json").write_text(json.dumps(payload))
        return self.states[thread_id]

    def send(self, thread_id, message):
        self.sends.append((thread_id, message))
        self.journal.append(("send", thread_id, message))
        self.states[thread_id] = ThreadState("active")

    def stop(self, thread_id, reason):
        self.stops.append((thread_id, reason))
        self.journal.append(("stop", thread_id, reason))
        self.states[thread_id] = ThreadState("failed", error=reason)

    def settle(self, thread_id):
        self.journal.append(("settle_attempt", thread_id))
        if self.settle_failures:
            self.settle_failures -= 1
            raise T3Error("settle unavailable")
        self.settles.append(thread_id)
        self.journal.append(("settle", thread_id))
        self.states[thread_id] = replace(self.states[thread_id], settled=True)

    def link(self, thread_id, url):
        self.links.append((thread_id, url))
        self.journal.append(("link", thread_id, url))
        if self.link_failures:
            self.link_failures -= 1
            raise T3Error("link unavailable")

    def catalog(self):
        return []


class Fetch:
    def __init__(self, journal):
        self.calls, self.journal, self.error = [], journal, None

    def __call__(self, checkout, forge_name, change):
        self.calls.append((Path(checkout), forge_name, change))
        self.journal.append(("fetch", forge_name, change.number))
        if self.error:
            raise self.error


class Notify:
    def __init__(self, journal):
        self.calls, self.journal = [], journal

    def __call__(self, title, body):
        self.calls.append((title, body))
        self.journal.append(("notify", title, body))

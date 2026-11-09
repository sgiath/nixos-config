"""Filip's threads after the comment: watch them for replies and fixes, apply the reviewer's judgment of each, and
settle the review once every thread is fixed or answered.

A thread is tracked from the moment the service posts it (store `threads`). While it is `open` or `disputed` the
poll reads it; a reply by anyone but Filip, or a new head that no normal review will look at, queues a `follow_up`
review at the MR's current head, and every review of a new head judges the open threads too. `fixed` and `answered`
threads get a short reply and are resolved; `disputed` ones wait for Filip's decision in the UI.

The service's own automated replies are not evidence: "the newest note" below always skips them, so a reply the
service posted is never mistaken for an answer and never changes which reply it would post.
"""

import json
from dataclasses import dataclass, field, replace
from datetime import UTC
from pathlib import Path

from . import bundle
from .forge.base import ForgeError
from .models import Note, Selection, Thread, Verdict
from .note import REPLY_MARK, own_markers, reply_body, reply_marker
from .rules import OPEN, eligibility, moved
from .settings import CONTRACT, repo_view
from .store import ACTIVE, SETTLED, WATCHED


@dataclass
class Applied:
    """What applying a verdict's judgments did: disputed and failed threads as readable lines, settled count."""

    disputed: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    settled: int = 0


class Threads:
    def __init__(self, engine):
        self.engine = engine

    # The poll

    def scan(self, settings: dict) -> None:
        """For every MR with an open or disputed thread: close tracking when the MR is closed, settle or stop watching
        threads resolved on the forge, stop follow-ups of an old head, mark Filip's own replies seen, and queue one
        follow-up for new replies by others, or for a new head no normal review will look at, unless a review of
        the MR is active (it, or the next poll, judges them)."""
        for repo_id, number in self.engine.store.watched():
            repo = settings["repos"].get(repo_id)
            if repo and repo["enabled"]:
                self.engine._guard(None, lambda r=repo_id, n=number: self._scan(settings, r, n))

    def _scan(self, settings: dict, repo_id: str, number: int) -> None:
        engine, store = self.engine, self.engine.store
        repo = repo_view(settings, repo_id)
        forge, me = engine.forges[repo["forge"]], engine.me(repo["forge"])
        change = forge.change(repo["path"], number, me)
        tracked = store.threads(repo_id, number, WATCHED)
        if change.state not in OPEN:
            for item in tracked:
                store.update_thread(repo_id, number, item["marker"], status="closed", updated_at=self._now())
            return
        for row in store.for_mr(repo_id, number):
            if row["status"] in ACTIVE and row["kind"] == "follow_up" and moved(row, change):
                engine._supersede(row, f"superseded by @{change.head_sha[:8]}")
        rows = store.for_mr(repo_id, number)
        active = any(r["status"] in ACTIVE for r in rows)
        found = self._locate(repo_id, number, tracked, forge.threads(repo["path"], number), me)
        pending = []
        for item in tracked:
            thread = found.get(item["marker"])
            if thread is None:
                continue
            if thread.resolved:
                self._resolved(item)
                continue
            newest = evidence(thread, me)
            if newest.id == item["last_note_id"]:
                continue
            if newest.author.casefold() == me.casefold():
                store.update_thread(repo_id, number, item["marker"], last_note_id=newest.id, updated_at=self._now())
            elif not active:
                pending.append(newest.id)
        # A pushed fix with nobody replying: discovery reviews the new head only while a review is requested.
        new_head = bool(rows) and rows[-1]["head_sha"] != change.head_sha
        if active or not (pending or (new_head and eligibility(change, repo["rules"], me).action == "skip")):
            return
        review_id = store.claim(
            change, forge=repo["forge"], path=repo["path"], selection=Selection(**repo["reviewer"]),
            contract=CONTRACT, now=self._now(), kind="follow_up", trigger=",".join(sorted(pending)) or "head",
        )
        if review_id:
            reason = (f"{len(pending)} new repl{'y' if len(pending) == 1 else 'ies'}" if pending
                      else f"new head @{change.head_sha[:8]}")
            engine.record("info", f"queued a follow-up on {reason} in {bundle.ref(repo['forge'], repo['path'], number)}",
                          review_id=review_id)

    def _resolved(self, item: dict) -> None:
        """Resolved on the forge: by the service itself when a settling write was in flight (its answer was lost),
        else by someone else, and no longer watched."""
        store = self.engine.store
        if item["pending"]:
            store.update_thread(item["repo"], item["number"], item["marker"], status=item["pending"], pending=None,
                                updated_at=self._now())
            return
        store.update_thread(item["repo"], item["number"], item["marker"], status="resolved_elsewhere",
                            updated_at=self._now())
        self.engine.record("info", f"{item['finding_id']} of review {item['review_id']} was resolved on the forge;"
                                   " no longer watched")

    # What a review reads

    def snapshot(self, row: dict, threads: list[Thread], me: str) -> tuple[list[dict], list[dict]]:
        """(own, settled) for the run directory: the open/disputed threads still unresolved on the forge, which the
        reviewer must judge, with every note; and the threads already fixed, answered or accepted, which are
        decided. `status` and `newest_note_id` are what apply() later checks the thread against."""
        store = self.engine.store
        tracked = store.threads(row["repo"], row["number"])
        watched = [t for t in tracked if t["status"] in WATCHED]
        found = self._locate(row["repo"], row["number"], watched, threads, me)
        own = []
        for item in watched:
            thread = found.get(item["marker"])
            if thread is None or thread.resolved:
                continue
            own.append({
                "thread_id": thread.id, "finding_id": item["finding_id"], "title": item["title"],
                "file": item["file"], "line": item["line"], "score": item["score"], "status": item["status"],
                "newest_note_id": evidence(thread, me).id,
                "notes": [{"id": n.id, "author": n.author, "body": bundle.AGENT_PROMPT.sub("", n.body)}
                          for n in thread.notes],
            })
        settled = [{"thread_id": t["thread_id"], "finding_id": t["finding_id"], "title": t["title"],
                    "status": t["status"]} for t in tracked if t["status"] in SETTLED]
        return own, settled

    def settled_ids(self, repo_id: str, number: int) -> frozenset[str]:
        return frozenset(t["thread_id"] for t in self.engine.store.threads(repo_id, number, SETTLED) if t["thread_id"])

    def watching(self, row: dict) -> list[dict]:
        """Threads of the MR still open or disputed that this attempt did not post."""
        return [t for t in self.engine.store.threads(row["repo"], row["number"], WATCHED)
                if (t["review_id"], t["attempt"]) != (row["id"], row["attempt"])]

    # Applying a verdict

    def apply(self, row: dict, verdict: Verdict, threads: list[Thread], me: str, *, record_only: bool) -> Applied:
        """Act on each judgment whose thread is unchanged since the review read it: same tracked status (a decision
        Filip made meanwhile wins) and same newest note (a newer reply is judged again by the next follow-up).
        fixed/answered -> reply once and resolve; open -> seen; disputed -> wait for Filip with the proposed reply.
        A failed settling write leaves the thread disputed for Filip, remembering what was intended. `record_only`
        (dry run, or a verdict that reported injection) stores the reasoning and writes nothing."""
        engine, store = self.engine, self.engine.store
        listed_path = engine.run_dir(row) / "mr/own_threads.json"
        listed = {t["thread_id"]: t for t in json.loads(listed_path.read_text())} if listed_path.exists() else {}
        tracked = {t["thread_id"]: t for t in store.threads(row["repo"], row["number"], WATCHED) if t["thread_id"]}
        current = {t.id: t for t in threads}
        forge = engine.forges[row["forge"]]
        result = Applied()
        for judgment in verdict.threads:
            item, seen, thread = (tracked.get(judgment.thread_id), listed.get(judgment.thread_id),
                                  current.get(judgment.thread_id))
            if item is None or seen is None or thread is None or thread.resolved:
                continue
            label = item["finding_id"]
            if item["status"] != seen["status"] or evidence(thread, me).id != seen["newest_note_id"]:
                engine.record("info", f"{label}: the thread changed since the review read it; judging it again later",
                              review_id=row["id"])
                continue

            def update(**fields):
                store.update_thread(row["repo"], row["number"], item["marker"], updated_at=self._now(), **fields)

            if record_only:
                update(reasoning=judgment.reasoning, proposed_reply=judgment.reply or None)
                continue
            seen_id = seen["newest_note_id"]
            if judgment.status in ("fixed", "answered"):
                operation = f"{judgment.thread_id}:{seen_id}"  # the same evidence never gets two replies
                update(pending=judgment.status)
                try:
                    if not replied(thread, operation, me):
                        forge.reply(row["path"], row["number"], judgment.thread_id,
                                    reply_body(me, judgment.reply, operation))
                    forge.resolve(row["path"], row["number"], judgment.thread_id)
                except ForgeError as error:
                    update(status="disputed", last_note_id=seen_id, proposed_reply=None,
                           reasoning=f"Closing it as {judgment.status} failed ({error}). {judgment.reasoning}")
                    result.errors.append(f"{label}: {error}")
                    engine.record("warn", f"closing {label} as {judgment.status} failed: {error}", review_id=row["id"])
                    continue
                update(status=judgment.status, pending=None, last_note_id=seen_id, proposed_reply=None,
                       reasoning=judgment.reasoning)
                result.settled += 1
                engine.record("info", f"{label} {judgment.status}: replied and resolved", review_id=row["id"])
            elif judgment.status == "disputed":
                update(status="disputed", last_note_id=seen_id, proposed_reply=judgment.reply,
                       reasoning=judgment.reasoning)
                result.disputed.append(f"{label}: {judgment.reasoning}")
                engine.record("info", f"{label}: the reply needs your decision", review_id=row["id"])
            else:
                update(last_note_id=seen_id, reasoning=judgment.reasoning)
        return result

    def reconsider(self, repo_id: str, number: int) -> None:
        """After threads were settled: when the latest finished review is at the MR's current head, read every file,
        found no injection, and each of its findings reaching the threshold now sits in a fixed, answered or accepted
        thread, with no thread of the MR still open or disputed: approve under `when_clean` if the MR is still ready
        under the repo's rules (draft, pipeline; the review request is not needed), else mark the MR reviewed
        (clears an earlier "requested changes" on GitLab)."""
        engine, store = self.engine, self.engine.store
        settings = engine.settings()
        if settings["dry_run"] or settings["paused"] or repo_id not in settings["repos"]:
            return
        repo = repo_view(settings, repo_id)
        reviews = [r for r in store.for_mr(repo_id, number) if r["kind"] == "review" and r["status"] == "done"]
        if not reviews or store.threads(repo_id, number, WATCHED):
            return
        row = reviews[-1]
        if row["dry_run"] or row["not_reviewed"] or row["injection_attempts"]:
            return
        tracked = store.threads(repo_id, number, SETTLED)
        settled_threads = {t["thread_id"] for t in tracked}
        settled_findings = {(t["review_id"], t["attempt"], t["finding_id"]) for t in tracked}
        for finding in store.findings(row["id"], row["attempt"]):
            state = finding["state"]
            if state in ("below", "settled"):
                continue
            if state == "posted" and (row["id"], row["attempt"], finding["finding_id"]) in settled_findings:
                continue
            if state in ("already_open", "already_resolved") and finding["existing_thread_id"] in settled_threads:
                continue
            return
        forge, me = engine.forges[row["forge"]], engine.me(row["forge"])
        change = forge.change(row["path"], row["number"], me)
        if moved(row, change):
            return
        if repo["approval"] != "when_clean":
            forge.mark_reviewed(row["path"], change)
            return
        ready = eligibility(replace(change, review_requested=True), repo["rules"], me)
        if row["approved"] or ready.action != "review":
            if not row["approved"]:
                engine.record("info", f"not approving yet: {ready.reason}", review_id=row["id"])
            return
        forge.approve(row["path"], change)
        store.update(row["id"], approved=True)
        engine.record("info", f"approved at @{row['head_sha'][:8]}: every comment is fixed or answered",
                      review_id=row["id"])

    # Filip's decisions on a disputed thread (explicit actions: like Post anyway they write even in dry run)

    def accept(self, key: tuple, reply: str | None) -> None:
        """Accept the author's answer: reply if text is given (once), resolve, and count the thread as fixed."""
        item, forge, thread = self._disputed(key, write=True)
        if reply and reply.strip():
            operation = f"{item['thread_id']}:accept:{item['last_note_id']}"
            if not replied(thread, operation, self._me(item)):
                forge.reply(item["path"], item["number"], item["thread_id"],
                            f"{reply.strip()}\n\n{reply_marker(operation)}")
        forge.resolve(item["path"], item["number"], item["thread_id"])
        self.engine.store.update_thread(*key, status="accepted", pending=None, proposed_reply=None,
                                        updated_at=self._now())
        self.engine.record("info", f"{item['finding_id']}: answer accepted and resolved", review_id=item["review_id"])
        self.reconsider(item["repo"], item["number"])

    def reply(self, key: tuple, body: str) -> None:
        """Post Filip's reply; the thread stays open and is watched again."""
        from .engine import ActionError

        if not body or not body.strip():
            raise ActionError("the reply is empty")
        item, forge, _ = self._disputed(key, write=True)
        forge.reply(item["path"], item["number"], item["thread_id"], body.strip())
        self.engine.store.update_thread(*key, status="open", pending=None, proposed_reply=None,
                                        updated_at=self._now())
        self.engine.record("info", f"{item['finding_id']}: replied, still open", review_id=item["review_id"])

    def dismiss(self, key: tuple) -> None:
        """Keep the thread open without writing anything."""
        item, _, _ = self._disputed(key, write=False)
        self.engine.store.update_thread(*key, status="open", pending=None, proposed_reply=None,
                                        updated_at=self._now())
        self.engine.record("info", f"{item['finding_id']}: kept open", review_id=item["review_id"])

    # Helpers

    def _disputed(self, key: tuple, *, write: bool) -> tuple[dict, object, Thread | None]:
        from .engine import ActionError

        item = self.engine.store.thread(*key)
        if item is None:
            raise ActionError("no such thread")
        if item["status"] != "disputed":
            raise ActionError(f"thread is {item['status']}")
        if not write:
            return item, None, None
        if self.engine.settings()["paused"]:
            raise ActionError("paused")
        if not item["thread_id"]:
            raise ActionError("the thread is not located on the forge yet")
        forge = self.engine.forges[item["forge"]]
        thread = next((t for t in forge.threads(item["path"], item["number"]) if t.id == item["thread_id"]), None)
        return item, forge, thread

    def _locate(self, repo_id: str, number: int, tracked: list[dict], threads: list[Thread], me: str) -> dict:
        """marker -> forge thread; a thread id first found by its marker is saved."""
        by_id = {t.id: t for t in threads}
        markers = None
        found = {}
        for item in tracked:
            thread_id = item["thread_id"]
            if not thread_id:
                markers = own_markers(threads, me) if markers is None else markers
                thread_id = markers.get(item["marker"], (None, None))[0]
                if thread_id:
                    self.engine.store.update_thread(repo_id, number, item["marker"], thread_id=thread_id)
            if thread_id in by_id:
                found[item["marker"]] = by_id[thread_id]
        return found

    def _me(self, item: dict) -> str:
        return self.engine.me(item["forge"])

    def _now(self) -> str:
        return self.engine.now().astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def evidence(thread: Thread, me: str) -> Note:
    """The newest note that is not one of the service's own replies."""
    for item in reversed(thread.notes):
        if not (item.author.casefold() == me.casefold() and REPLY_MARK in item.body):
            return item
    return thread.notes[0]


def replied(thread: Thread | None, operation: str, me: str) -> bool:
    """Whether the reply of `operation` is already in the thread (its answer may have been lost)."""
    mark = reply_marker(operation)
    return bool(thread) and any(n.author.casefold() == me.casefold() and mark in n.body for n in thread.notes)


def write(run_dir: Path, own: list[dict], settled: list[dict]) -> None:
    (run_dir / "mr/own_threads.json").write_text(json.dumps(own, indent=2, ensure_ascii=False) + "\n")
    (run_dir / "mr/settled_threads.json").write_text(json.dumps(settled, indent=2, ensure_ascii=False) + "\n")

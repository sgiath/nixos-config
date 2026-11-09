"""Filip's threads after the comment: watch them for replies, apply the reviewer's judgment of each, and settle the
review once every thread is fixed or answered.

A thread is tracked from the moment the service posts it (store `threads`). While it is `open` or `disputed` the
poll reads it; a reply by anyone but Filip queues a `follow_up` review at the MR's current head, and every review
of a new head judges the open threads too. `fixed` and `answered` threads get a short reply and are resolved;
`disputed` ones wait for Filip's decision in the UI.
"""

import json
from datetime import UTC
from pathlib import Path

from . import bundle
from .forge.base import ForgeError
from .models import Selection, Thread, Verdict
from .note import own_markers, reply_body, reply_marker, review_key
from .rules import OPEN, moved
from .settings import CONTRACT, repo_view
from .store import ACTIVE, SETTLED, WATCHED


class Threads:
    def __init__(self, engine):
        self.engine = engine

    # The poll

    def scan(self, settings: dict) -> None:
        """For every MR with an open or disputed thread: close tracking when the MR is closed, stop watching threads
        someone resolved, mark Filip's own replies seen, and queue one follow-up for new replies by others unless a
        review of the MR is active (it, or the next poll, judges them)."""
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
        found = self._locate(repo_id, number, tracked, forge.threads(repo["path"], number), me)
        active = any(r["status"] in ACTIVE for r in store.for_mr(repo_id, number))
        pending = []
        for item in tracked:
            thread = found.get(item["marker"])
            if thread is None:
                continue
            if thread.resolved:
                store.update_thread(repo_id, number, item["marker"], status="resolved_elsewhere",
                                    updated_at=self._now())
                engine.record("info", f"{item['finding_id']} of review {item['review_id']} was resolved on the forge;"
                                      " no longer watched")
                continue
            newest = thread.notes[-1]
            if newest.id == item["last_note_id"]:
                continue
            if newest.author.casefold() == me.casefold():
                store.update_thread(repo_id, number, item["marker"], last_note_id=newest.id, updated_at=self._now())
            elif not active:
                pending.append(newest.id)
        if not pending:
            return
        review_id = store.claim(
            change, forge=repo["forge"], path=repo["path"], selection=Selection(**repo["reviewer"]),
            contract=CONTRACT, now=self._now(), kind="follow_up", trigger=",".join(sorted(pending)),
        )
        if review_id:
            engine.record("info", f"queued a follow-up on {len(pending)} new repl{'y' if len(pending) == 1 else 'ies'}"
                                  f" in {bundle.ref(repo['forge'], repo['path'], number)}", review_id=review_id)

    # What a review reads

    def snapshot(self, row: dict, threads: list[Thread], me: str) -> tuple[list[dict], list[dict]]:
        """(own, settled) for the run directory: the open/disputed threads still unresolved on the forge, which the
        reviewer must judge, with every note; and the threads already fixed, answered or accepted, which are
        decided."""
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
                "newest_note_id": thread.notes[-1].id,
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

    def apply(self, row: dict, verdict: Verdict, threads: list[Thread], me: str, *, dry_run: bool) -> tuple[list, list]:
        """Act on each judgment of a thread that is still open or disputed (a decision Filip made meanwhile wins):
        fixed/answered -> reply once and resolve; open -> seen; disputed -> wait for Filip with the proposed reply.
        Dry run only records the reasoning. Returns (disputed, errors) as readable lines."""
        engine, store = self.engine, self.engine.store
        listed_path = engine.run_dir(row) / "mr/own_threads.json"
        listed = {t["thread_id"]: t for t in json.loads(listed_path.read_text())} if listed_path.exists() else {}
        tracked = {t["thread_id"]: t for t in store.threads(row["repo"], row["number"], WATCHED) if t["thread_id"]}
        forge_threads = {t.id: t for t in threads}
        forge, key = engine.forges[row["forge"]], review_key(row)
        disputed, errors = [], []
        for judgment in verdict.threads:
            item, seen = tracked.get(judgment.thread_id), listed.get(judgment.thread_id)
            if item is None or seen is None:
                continue
            update = lambda **fields: store.update_thread(row["repo"], row["number"], item["marker"],  # noqa: E731
                                                          updated_at=self._now(), reasoning=judgment.reasoning,
                                                          **fields)
            label = item["finding_id"]
            if dry_run:
                update(proposed_reply=judgment.reply or None)
                continue
            if judgment.status in ("fixed", "answered"):
                try:
                    current = forge_threads.get(judgment.thread_id)
                    if not (current and _replied(current, key, me)):
                        forge.reply(row["path"], row["number"], judgment.thread_id, reply_body(me, judgment.reply, key))
                    forge.resolve(row["path"], row["number"], judgment.thread_id)
                except ForgeError as error:
                    errors.append(f"{label}: {error}")
                    engine.record("warn", f"closing {label} as {judgment.status} failed: {error}", review_id=row["id"])
                    continue
                update(status=judgment.status, last_note_id=seen["newest_note_id"], proposed_reply=None)
                engine.record("info", f"{label} {judgment.status}: replied and resolved", review_id=row["id"])
            elif judgment.status == "disputed":
                update(status="disputed", last_note_id=seen["newest_note_id"], proposed_reply=judgment.reply)
                disputed.append(f"{label}: {judgment.reasoning}")
                engine.record("info", f"{label}: the reply needs your decision", review_id=row["id"])
            else:
                update(last_note_id=seen["newest_note_id"])
        return disputed, errors

    def reconsider(self, repo_id: str, number: int, settings: dict) -> None:
        """After threads were settled: when the latest finished review is at the MR's current head, read every file,
        found no injection, and each of its findings reaching the threshold now sits in a fixed, answered or accepted
        thread, with no thread of the MR still open or disputed: approve under `when_clean`, else mark the MR
        reviewed (clears an earlier "requested changes" on GitLab)."""
        engine, store = self.engine, self.engine.store
        if settings["dry_run"] or repo_id not in settings["repos"]:
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
        if repo["approval"] == "when_clean":
            if not row["approved"]:
                forge.approve(row["path"], change)
                store.update(row["id"], approved=True)
                engine.record("info", f"approved at @{row['head_sha'][:8]}: every comment is fixed or answered",
                              review_id=row["id"])
        else:
            forge.mark_reviewed(row["path"], change)

    # Filip's decisions on a disputed thread

    def accept(self, key: tuple, reply: str | None) -> None:
        """Accept the author's answer: reply if text is given, resolve, and count the thread as fixed."""
        item, forge = self._disputed(key, write=True)
        if reply and reply.strip():
            forge.reply(item["path"], item["number"], item["thread_id"], reply.strip())
        forge.resolve(item["path"], item["number"], item["thread_id"])
        self.engine.store.update_thread(*key, status="accepted", proposed_reply=None, updated_at=self._now())
        self.engine.record("info", f"{item['finding_id']}: answer accepted and resolved", review_id=item["review_id"])
        self.reconsider(item["repo"], item["number"], self.engine.settings())

    def reply(self, key: tuple, body: str) -> None:
        """Post Filip's reply; the thread stays open and is watched again."""
        from .engine import ActionError

        if not body or not body.strip():
            raise ActionError("the reply is empty")
        item, forge = self._disputed(key, write=True)
        forge.reply(item["path"], item["number"], item["thread_id"], body.strip())
        self.engine.store.update_thread(*key, status="open", proposed_reply=None, updated_at=self._now())
        self.engine.record("info", f"{item['finding_id']}: replied, still open", review_id=item["review_id"])

    def dismiss(self, key: tuple) -> None:
        """Keep the thread open without writing anything."""
        item, _ = self._disputed(key, write=False)
        self.engine.store.update_thread(*key, status="open", proposed_reply=None, updated_at=self._now())
        self.engine.record("info", f"{item['finding_id']}: kept open", review_id=item["review_id"])

    # Helpers

    def _disputed(self, key: tuple, *, write: bool) -> tuple[dict, object]:
        from .engine import ActionError

        item = self.engine.store.thread(*key)
        if item is None:
            raise ActionError("no such thread")
        if item["status"] != "disputed":
            raise ActionError(f"thread is {item['status']}")
        if write and self.engine.settings()["paused"]:
            raise ActionError("paused")
        if write and not item["thread_id"]:
            raise ActionError("the thread is not located on the forge yet")
        return item, self.engine.forges[item["forge"]]

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

    def _now(self) -> str:
        return self.engine.now().astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def _replied(thread: Thread, key: str, me: str) -> bool:
    """Whether this review already replied in the thread (its answer may have been lost)."""
    mark = reply_marker(key)
    return any(n.author.casefold() == me.casefold() and mark in n.body for n in thread.notes)


def write(run_dir: Path, own: list[dict], settled: list[dict]) -> None:
    (run_dir / "mr/own_threads.json").write_text(json.dumps(own, indent=2, ensure_ascii=False) + "\n")
    (run_dir / "mr/settled_threads.json").write_text(json.dumps(settled, indent=2, ensure_ascii=False) + "\n")

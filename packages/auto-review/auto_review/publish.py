"""Turn a finished thread's verdict into comments, an approval and a finished review."""

from . import bundle
from .diffs import DiffIndex
from .forge.base import ForgeError
from .models import Comment, Finding
from .note import DEFAULT_TEMPLATE, comment_body, marker, own_markers
from .rules import eligibility, moved
from .settings import repo_view
from .verdict import VerdictError, decide, load

POST_ATTEMPTS = 3


class Publisher:
    def __init__(self, engine):
        self.engine = engine
        self._post_failures: dict[tuple[int, int], int] = {}  # (review id, attempt) -> consecutive failures

    def publish(self, row: dict, settings: dict) -> None:
        """`deciding`/`posting` -> `done`, or stays put while paused, in quiet hours, waiting for the change to be
        ready again, or after a failed write (the next tick resumes and recognises what was already posted)."""
        engine, store = self.engine, self.engine.store
        settings = engine.settings()
        if settings["paused"] or engine.quiet(engine.now())[0]:
            return
        if row["repo"] not in settings["repos"]:
            return engine.fail(row, "repo is no longer watched")
        repo = repo_view(settings, row["repo"])
        run_dir = engine.run_dir(row)
        try:
            verdict = load(run_dir / "verdict.json", review_id=row["id"], attempt=row["attempt"],
                           head_sha=row["head_sha"], base_sha=row["base_sha"])
            forge, me = engine.forges[row["forge"]], engine.me(row["forge"])
            change = forge.change(row["path"], row["number"], me)
            threads = forge.threads(row["path"], row["number"])
            decision = decide(verdict, threshold=repo["threshold"], index=DiffIndex(bundle.diffs(run_dir)),
                              threads=threads)
        except VerdictError as error:
            return engine.fail(row, f"verdict rejected: {error}")

        allowed = eligibility(change, repo["rules"], me)
        held = moved(row, change) or (allowed.reason if allowed.action == "skip" else None)
        if not held and allowed.action == "wait":
            return
        dry_run = settings["dry_run"]
        stored = {f["finding_id"]: f for f in store.findings(row["id"], row["attempt"])}
        rows = []
        for placed in decision.placed:
            state = placed.state
            if state == "post":
                state = "not_posted" if held else "would_post" if dry_run else "post"
            previous = stored.get(placed.finding.id)
            if previous and previous["state"] == "posted":
                rows.append(previous)
            else:
                rows.append(_finding_row(placed.finding, state))
        store.save_findings(row["id"], row["attempt"], rows)
        store.update(row["id"], summary=verdict.summary, not_reviewed=list(verdict.not_reviewed),
                     injection_attempts=list(verdict.injection_attempts), outcome=decision.outcome, dry_run=dry_run)
        blocking = _blocking(decision, repo)
        if held or dry_run:
            note = f"not posted: {held}" if held else "dry run: nothing posted"
            if dry_run and not held and blocking:
                note += f", would request changes ({blocking})"
            return self._done(row, decision.outcome, note)

        if self._changed(settings, row["repo"]):
            return  # paused, dry run or policy changed from the UI during the reads above; decide again next tick
        store.update(row["id"], status="posting")
        pending = [p for p in decision.to_post() if stored.get(p.finding.id, {}).get("state") != "posted"]
        if pending and not self._post(row, repo, change, threads, me, pending):
            return
        posted = any(f["state"] == "posted" for f in store.findings(row["id"], row["attempt"]))
        if posted or blocking:
            try:
                if blocking:
                    forge.request_changes(row["path"], change)
                    engine.record("info", f"requested changes: {blocking}", review_id=row["id"])
                else:
                    forge.mark_reviewed(row["path"], change)
            except ForgeError as error:
                engine.record("warn", f"setting the review state failed: {error}", review_id=row["id"])
        if repo["approval"] == "when_clean" and decision.approvable and not row["approved"]:
            if self._changed(settings, row["repo"]):
                return
            try:
                forge.approve(row["path"], change)
            except ForgeError as error:
                return engine.fail(row, f"approval failed: {error}")
            store.update(row["id"], approved=True)
            engine.record("info", f"approved at @{row['head_sha'][:8]}", review_id=row["id"])
        self._done(row, decision.outcome, decision.reason)

    def post_anyway(self, row: dict, finding_id: str) -> None:
        from .engine import ActionError

        engine, store = self.engine, self.engine.store
        if row["status"] != "done":
            raise ActionError(f"review is {row['status']}")
        settings = engine.settings()
        if settings["paused"]:
            raise ActionError("paused")
        found = next((f for f in store.findings(row["id"], row["attempt"]) if f["finding_id"] == finding_id), None)
        if found is None or found["state"] not in ("below", "would_post"):
            raise ActionError(f"finding {finding_id} is {found['state'] if found else 'unknown'}")
        if row["repo"] not in settings["repos"]:
            raise ActionError("repo is no longer watched")
        forge, me = engine.forges[row["forge"]], engine.me(row["forge"])
        change = forge.change(row["path"], row["number"], me)
        if reason := moved(row, change):
            raise ActionError(reason)
        anchor = DiffIndex(bundle.diffs(engine.run_dir(row))).anchor(found["file"], found["side"], found["line"])
        if anchor is None:
            raise ActionError(f"{finding_id} has no line in the diff")
        repo = repo_view(settings, row["repo"])
        finding = _finding(found)
        key = review_key(row)
        mark = marker(key, finding.id)
        if mark in (markers := own_markers(forge.threads(row["path"], row["number"]), me)):
            thread_id, note = markers[mark]  # an earlier request was posted but its answer was lost
            store.update_finding(row["id"], row["attempt"], finding_id, state="posted",
                                 url=_note_url(row["forge"], change.url, note.id), remote_id=thread_id)
            return
        body = comment_body(_template(settings), finding, _values(row, repo, finding, me), key)
        [receipt] = forge.post(row["path"], change, [Comment(finding.id, anchor, body, mark)])
        store.update_finding(row["id"], row["attempt"], finding_id, state="posted", url=receipt.url,
                             remote_id=receipt.id)
        engine.record("info", f"posted {finding_id} on request", review_id=row["id"])

    def _post(self, row, repo, change, threads, me, pending) -> bool:
        """Post what is not posted yet; False when a write failed (retried next tick)."""
        engine, store = self.engine, self.engine.store
        key = review_key(row)
        markers = own_markers(threads, me)
        comments = []
        for placed in pending:
            mark = marker(key, placed.finding.id)
            if mark in markers:
                thread_id, note = markers[mark]
                store.update_finding(row["id"], row["attempt"], placed.finding.id, state="posted",
                                     url=_note_url(row["forge"], change.url, note.id), remote_id=thread_id)
                continue
            body = comment_body(_template(engine.settings()), placed.finding,
                                _values(row, repo, placed.finding, me), key)
            comments.append(Comment(placed.finding.id, placed.anchor, body, mark))
        if not comments:
            self._posted(row)
            return True
        try:
            receipts = engine.forges[row["forge"]].post(row["path"], change, comments)
        except ForgeError as error:
            attempt = (row["id"], row["attempt"])
            failures = self._post_failures.get(attempt, 0) + 1
            self._post_failures[attempt] = failures
            if failures >= POST_ATTEMPTS:
                self._post_failures.pop(attempt, None)
                engine.fail(row, f"posting failed {failures} times: {error}")
            else:
                store.update(row["id"], error=f"posting failed, will retry: {error}")
                engine.record("warn", f"posting failed, will retry: {error}", review_id=row["id"])
            return False
        self._posted(row)
        for receipt in receipts:
            store.update_finding(row["id"], row["attempt"], receipt.finding_id, state="posted", url=receipt.url,
                                 remote_id=receipt.id)
        engine.record("info", f"posted {', '.join(r.finding_id for r in receipts)}", review_id=row["id"])
        return True

    def _posted(self, row: dict) -> None:
        """Everything pending is on the forge now: forget earlier failures of this attempt."""
        if self._post_failures.pop((row["id"], row["attempt"]), None) or (row["error"] or "").startswith("posting"):
            self.engine.store.update(row["id"], error=None)

    def _changed(self, settings: dict, repo_id: str) -> bool:
        """Whether a write must wait: paused or quiet now, or dry run or the repo's approval policy differ from the
        settings this decision was made with."""
        current = self.engine.settings()
        if current["paused"] or self.engine.quiet(self.engine.now())[0]:
            return True
        if current["dry_run"] != settings["dry_run"] or repo_id not in current["repos"]:
            return True
        return current["repos"][repo_id]["approval"] != settings["repos"][repo_id]["approval"]

    def _done(self, row: dict, outcome: str, note: str) -> None:
        engine = self.engine
        engine.finish(row, "done", outcome=outcome)
        engine.record("info", f"done: {outcome}; {note}", review_id=row["id"])
        if outcome == "needs_attention":
            engine.notify(f"Review needs you: {bundle.ref(row['forge'], row['path'], row['number'])}", note)


def review_key(row: dict) -> str:
    """Names one attempt at one diff in the hidden marker of each comment it posts."""
    return (f"{row['repo']}:{row['number']}:{row['head_sha'][:12]}:{row['base_sha'][:12]}:{row['target']}"
            f":{row['attempt']}")


def _template(settings: dict) -> str:
    return settings["note_template"] or DEFAULT_TEMPLATE


def _values(row: dict, repo: dict, finding: Finding, me: str) -> dict:
    return {
        "reviewer": me, "provider": row["provider"], "model": row["model"], "effort": row["effort"],
        "harness": harness(row["provider"]), "repo": row["path"], "number": row["number"],
        "head_sha": row["head_sha"], "head_short": row["head_sha"][:8], "finding_id": finding.id,
        "title": finding.title, "frequency": finding.frequency, "severity": finding.severity,
        "score": finding.score, "threshold": repo["threshold"], "disposition": "open",
    }


def _blocking(decision, repo: dict) -> str:
    """The findings that request changes: posted (or about to be) or already open, scoring at least the repo's
    `request_changes_threshold`, as "SR-1 (30), SR-3 (42)"; empty when none does."""
    found = [p.finding for p in decision.placed if p.state in ("post", "already_open")
             and p.finding.score >= repo["request_changes_threshold"]]
    return ", ".join(f"{f.id} ({f.score})" for f in found)


def harness(provider: str) -> str:
    if provider.startswith("claudeAgent"):
        return "Claude Code harness"
    if provider.startswith("codex"):
        return "Codex harness"
    return provider


def _note_url(forge: str, url: str, note_id: str) -> str:
    return f"{url}#note_{note_id}" if forge == "gitlab" else f"{url}#discussion_r{note_id}"


def _finding_row(finding: Finding, state: str) -> dict:
    return {
        "finding_id": finding.id, "title": finding.title, "frequency": finding.frequency,
        "severity": finding.severity, "score": finding.score, "file": finding.file, "side": finding.side,
        "line": finding.line, "existing_thread_id": finding.existing_thread_id, "body": finding.body,
        "reasoning": finding.reasoning, "state": state, "url": None, "remote_id": None,
    }


def _finding(row: dict) -> Finding:
    return Finding(
        id=row["finding_id"], title=row["title"], frequency=row["frequency"], severity=row["severity"],
        file=row["file"], side=row["side"], line=row["line"], body=row["body"], reasoning=row["reasoning"] or "",
        existing_thread_id=row["existing_thread_id"],
    )

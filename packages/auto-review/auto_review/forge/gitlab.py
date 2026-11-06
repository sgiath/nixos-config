"""GitLab through `glab api`, with glab's own login."""

import json
import tempfile
from urllib.parse import quote, urlencode

from ..models import Change, Comment, FileDiff, Note, Posted, Thread
from ..proc import CommandError, concat_pages, run
from .base import ForgeError

FAILED_PIPELINES = {"failed", "canceled"}


class GitLab:
    name = "gitlab"

    def whoami(self) -> str:
        return self._get("user")["username"]

    def candidates(self, path: str, me: str, include_authors: list[str]) -> list[int]:
        queries = [{"reviewer_username": me}] + [{"author_username": author} for author in include_authors]
        found: list[int] = []
        for query in queries:
            for item in self._get_all(f"{_project(path)}/merge_requests", {"state": "opened", **query}):
                if item["iid"] not in found:
                    found.append(item["iid"])
        return found

    def change(self, path: str, number: int, me: str) -> Change:
        mr = self._get(f"{_project(path)}/merge_requests/{number}")
        refs = mr.get("diff_refs") or {}
        reviewers = tuple(r["username"] for r in mr.get("reviewers", []))
        return Change(
            repo=f"gitlab:{path}",
            number=mr["iid"],
            title=mr["title"],
            url=mr["web_url"],
            author=mr["author"]["username"],
            state=mr["state"],
            draft=bool(mr.get("draft")),
            labels=tuple(mr.get("labels", [])),
            head_sha=mr["sha"],
            base_sha=refs.get("base_sha") or "",
            target=mr["target_branch"],
            pipeline=_pipeline((mr.get("head_pipeline") or {}).get("status")),
            reviewers=reviewers,
            review_requested=me.lower() in {r.lower() for r in reviewers},
            diff_refs=refs,
            description=mr.get("description") or "",
        )

    def diffs(self, path: str, change: Change) -> list[FileDiff]:
        return [
            FileDiff(
                old_path=d["old_path"],
                new_path=d["new_path"],
                patch=d.get("diff") or "",
                truncated=bool(d.get("too_large") or d.get("collapsed")),
            )
            for d in self._get_all(f"{_project(path)}/merge_requests/{change.number}/diffs")
        ]

    def threads(self, path: str, number: int) -> list[Thread]:
        threads = []
        for discussion in self._get_all(f"{_project(path)}/merge_requests/{number}/discussions"):
            notes = [n for n in discussion.get("notes", []) if not n.get("system")]
            if not notes:
                continue
            resolvable = [n for n in notes if n.get("resolvable")]
            position = notes[0].get("position") or {}
            threads.append(
                Thread(
                    id=discussion["id"],
                    resolved=bool(resolvable) and all(n.get("resolved") for n in resolvable),
                    notes=tuple(Note(n["author"]["username"], n.get("body") or "", str(n["id"])) for n in notes),
                    path=position.get("new_path") or position.get("old_path"),
                    line=position.get("new_line") or position.get("old_line"),
                )
            )
        return threads

    def post(self, path: str, change: Change, comments: list[Comment]) -> list[Posted]:
        posted = []
        for comment in comments:
            payload = {"body": comment.body, "position": _position(change, comment)}
            try:
                created = json.loads(self._post(f"{_project(path)}/merge_requests/{change.number}/discussions", payload))
            except (CommandError, ValueError) as error:
                raise ForgeError(f"posting {comment.finding_id} on {change.url}: {error}") from error
            note_id = created["notes"][0]["id"]
            posted.append(Posted(comment.finding_id, created["id"], f"{change.url}#note_{note_id}"))
        return posted

    def mark_reviewed(self, path: str, change: Change) -> None:
        self._set_state(path, change, "reviewed")

    def request_changes(self, path: str, change: Change) -> None:
        self._set_state(path, change, "requested_changes")

    def _set_state(self, path: str, change: Change, state: str) -> None:
        """Publishing with no drafts only sets the state; with drafts pending it would publish Filip's drafts too."""
        base = f"{_project(path)}/merge_requests/{change.number}"
        if self._get_all(f"{base}/draft_notes"):
            return
        try:
            self._post(f"{base}/draft_notes/bulk_publish", {"reviewer_state": state})
        except CommandError as error:
            raise ForgeError(f"setting {change.url} to {state}: {error}") from error

    def approve(self, path: str, change: Change) -> None:
        approvals = self._get(f"{_project(path)}/merge_requests/{change.number}/approvals")
        me = self.whoami()
        if me in {a["user"]["username"] for a in approvals.get("approved_by", [])}:
            return
        try:
            run(["glab", "mr", "approve", str(change.number), "-R", path, "--sha", change.head_sha], timeout=60)
        except CommandError as error:
            raise ForgeError(f"approving {change.url} at {change.head_sha[:8]}: {error}") from error

    def discovered(self, me: str) -> list[dict]:
        items = self._get_all("merge_requests", {"scope": "all", "state": "opened", "reviewer_username": me})
        return [
            {
                "forge": self.name,
                "path": item["references"]["full"].rsplit("!", 1)[0],
                "number": item["iid"],
                "title": item["title"],
                "url": item["web_url"],
            }
            for item in items
        ]

    def _get(self, path: str, params: dict | None = None):
        try:
            return json.loads(run(["glab", "api", _url(path, params)], timeout=60))
        except (CommandError, ValueError) as error:
            raise ForgeError(f"GET {path}: {error}") from error

    def _get_all(self, path: str, params: dict | None = None) -> list:
        try:
            out = run(["glab", "api", "--paginate", _url(path, {"per_page": 100, **(params or {})})], timeout=180)
            return concat_pages(out)
        except (CommandError, ValueError) as error:
            raise ForgeError(f"GET {path}: {error}") from error

    @staticmethod
    def _post(path: str, payload: dict) -> str:
        with tempfile.NamedTemporaryFile("w", suffix=".json") as handle:
            json.dump(payload, handle)
            handle.flush()
            cmd = ["glab", "api", "--method", "POST", path, "--header", "Content-Type: application/json"]
            return run([*cmd, "--input", handle.name], timeout=60)


def _project(path: str) -> str:
    return f"projects/{quote(path, safe='')}"


def _url(path: str, params: dict | None) -> str:
    return f"{path}?{urlencode(params, quote_via=quote)}" if params else path


def _pipeline(status: str | None) -> str:
    if status is None:
        return "none"
    if status == "success":
        return "success"
    if status in FAILED_PIPELINES:
        return "failed"
    return "running"


def _position(change: Change, comment: Comment) -> dict:
    refs = change.diff_refs
    anchor = comment.anchor
    data = {
        "position_type": "text",
        "base_sha": refs["base_sha"],
        "start_sha": refs["start_sha"],
        "head_sha": refs["head_sha"],
        "old_path": anchor.old_path,
        "new_path": anchor.new_path,
        "old_line": anchor.old_line,
        "new_line": anchor.new_line,
    }
    return {k: v for k, v in data.items() if v is not None}

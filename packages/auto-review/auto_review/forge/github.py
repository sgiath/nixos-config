"""GitHub through `gh`, with gh's login (GH_TOKEN from the service's key wrapper)."""

import json
import tempfile
from urllib.parse import quote

from ..models import Change, Comment, FileDiff, Note, Posted, Thread
from ..proc import CommandError, concat_pages, run
from .base import ForgeError

THREADS_QUERY = (
    "query($owner:String!,$name:String!,$number:Int!,$endCursor:String){repository(owner:$owner,name:$name)"
    "{pullRequest(number:$number){reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor}"
    " nodes{id isResolved comments(first:100){nodes{databaseId author{login} body path line originalLine url}}}}}}}"
)
PR_FIELDS = "number,title,body,url,state,isDraft,author,labels,headRefOid,baseRefName,baseRefOid,reviewRequests,statusCheckRollup"
FAILED = {"FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE", "ERROR"}
PASSED = {"SUCCESS", "NEUTRAL", "SKIPPED"}


class GitHub:
    name = "github"

    def whoami(self) -> str:
        return self._get("user")["login"]

    def candidates(self, path: str, me: str, include_authors: list[str]) -> list[int]:
        authors = {a.lower() for a in include_authors}
        found = []
        for pr in self._get_all(f"repos/{path}/pulls?state=open&per_page=100"):
            requested = {r["login"].lower() for r in pr.get("requested_reviewers", [])}
            if me.lower() in requested or pr["user"]["login"].lower() in authors:
                found.append(pr["number"])
        return found

    def change(self, path: str, number: int, me: str) -> Change:
        try:
            pr = json.loads(run(["gh", "pr", "view", str(number), "-R", path, "--json", PR_FIELDS], timeout=60))
        except (CommandError, ValueError) as error:
            raise ForgeError(f"gh pr view {path}#{number}: {error}") from error
        compare = self._get(f"repos/{path}/compare/{pr['baseRefOid']}...{pr['headRefOid']}")
        requested = tuple(r["login"] for r in pr.get("reviewRequests", []) if r.get("login"))
        return Change(
            repo=f"github:{path}",
            number=pr["number"],
            title=pr["title"],
            url=pr["url"],
            author=pr["author"]["login"],
            state="opened" if pr["state"] == "OPEN" else pr["state"].lower(),
            draft=bool(pr.get("isDraft")),
            labels=tuple(label["name"] for label in pr.get("labels", [])),
            head_sha=pr["headRefOid"],
            base_sha=compare["merge_base_commit"]["sha"],
            target=pr["baseRefName"],
            pipeline=_checks(pr.get("statusCheckRollup") or []),
            reviewers=requested,
            review_requested=me.lower() in {r.lower() for r in requested},
            description=pr.get("body") or "",
        )

    def diffs(self, path: str, change: Change) -> list[FileDiff]:
        files = self._get_all(f"repos/{path}/pulls/{change.number}/files?per_page=100")
        return [
            FileDiff(
                old_path=f.get("previous_filename") or f["filename"],
                new_path=f["filename"],
                patch=f.get("patch") or "",
                truncated="patch" not in f and f.get("changes", 0) > 0,
            )
            for f in files
        ]

    def threads(self, path: str, number: int) -> list[Thread]:
        owner, name = path.split("/", 1)
        cmd = ["gh", "api", "graphql", "--paginate", "-f", f"query={THREADS_QUERY}",
               "-F", f"owner={owner}", "-F", f"name={name}", "-F", f"number={number}"]
        try:
            out = run(cmd, timeout=120)
        except CommandError as error:
            raise ForgeError(f"review threads of {path}#{number}: {error}") from error
        threads = []
        for page in _json_objects(out):
            for node in page["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]:
                comments = node["comments"]["nodes"]
                first = comments[0] if comments else {}
                threads.append(
                    Thread(
                        id=node["id"],
                        resolved=node["isResolved"],
                        notes=tuple(
                            Note((c.get("author") or {}).get("login", ""), c.get("body") or "", str(c["databaseId"]))
                            for c in comments
                        ),
                        path=first.get("path"),
                        line=first.get("line") or first.get("originalLine"),
                    )
                )
        return threads

    def post(self, path: str, change: Change, comments: list[Comment]) -> list[Posted]:
        """One review comment each (`pulls/N/comments`): a `COMMENT` review would need a top-level body, which is
        exactly the floating comment this service never writes."""
        posted = []
        for comment in comments:
            anchor = comment.anchor
            payload = {
                "body": comment.body,
                "commit_id": change.head_sha,
                "path": anchor.new_path if anchor.side == "new" else anchor.old_path,
                "line": anchor.line,
                "side": "RIGHT" if anchor.side == "new" else "LEFT",
            }
            created = self._post(f"repos/{path}/pulls/{change.number}/comments", payload)
            posted.append(Posted(comment.finding_id, str(created["id"]), created["html_url"]))
        return posted

    def mark_reviewed(self, path: str, change: Change) -> None:
        return None

    def request_changes(self, path: str, change: Change) -> None:
        # FIXME: GitHub requires a review body for REQUEST_CHANGES, which would be a floating comment; the inline
        # comments stand alone. Change this only if GitHub accepts a body-less REQUEST_CHANGES review.
        return None

    def approve(self, path: str, change: Change) -> None:
        me = self.whoami().lower()
        for review in self._get_all(f"repos/{path}/pulls/{change.number}/reviews?per_page=100"):
            mine = (review.get("user") or {}).get("login", "").lower() == me
            if mine and review["state"] == "APPROVED" and review.get("commit_id") == change.head_sha:
                return
        self._post(f"repos/{path}/pulls/{change.number}/reviews", {"commit_id": change.head_sha, "event": "APPROVE"})

    def discovered(self, me: str) -> list[dict]:
        query = quote("is:pr is:open review-requested:@me archived:false")
        found = self._get(f"search/issues?q={query}&per_page=100")
        return [
            {
                "forge": self.name,
                "path": item["repository_url"].split("/repos/", 1)[1],
                "number": item["number"],
                "title": item["title"],
                "url": item["html_url"],
            }
            for item in found.get("items", [])
        ]

    def _get(self, path: str):
        try:
            return json.loads(run(["gh", "api", path], timeout=60))
        except (CommandError, ValueError) as error:
            raise ForgeError(f"GET {path}: {error}") from error

    def _get_all(self, path: str) -> list:
        try:
            return concat_pages(run(["gh", "api", "--paginate", path], timeout=180))
        except (CommandError, ValueError) as error:
            raise ForgeError(f"GET {path}: {error}") from error

    def _post(self, path: str, payload: dict) -> dict:
        with tempfile.NamedTemporaryFile("w", suffix=".json") as handle:
            json.dump(payload, handle)
            handle.flush()
            try:
                return json.loads(run(["gh", "api", "--method", "POST", path, "--input", handle.name], timeout=60))
            except (CommandError, ValueError) as error:
                raise ForgeError(f"POST {path}: {error}") from error


def _checks(rollup: list[dict]) -> str:
    if not rollup:
        return "none"
    states = []
    for check in rollup:
        if check.get("__typename") == "StatusContext":
            states.append(check.get("state") or "PENDING")
        elif check.get("status") != "COMPLETED":
            states.append("PENDING")
        else:
            states.append(check.get("conclusion") or "PENDING")
    if any(s in FAILED for s in states):
        return "failed"
    if all(s in PASSED for s in states):
        return "success"
    return "running"


def _json_objects(out: str) -> list[dict]:
    decoder = json.JSONDecoder()
    objects, index = [], 0
    while index < len(out):
        while index < len(out) and out[index].isspace():
            index += 1
        if index >= len(out):
            break
        value, index = decoder.raw_decode(out, index)
        objects.append(value)
    return objects

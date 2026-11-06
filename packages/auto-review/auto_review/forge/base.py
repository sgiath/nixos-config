"""The interface each forge implements. Every write is pinned to the reviewed head where the forge allows it."""

from typing import Protocol

from ..models import Change, Comment, FileDiff, Posted, Thread


class ForgeError(Exception):
    pass


class Forge(Protocol):
    name: str

    def whoami(self) -> str:
        """The authenticated username."""

    def candidates(self, path: str, me: str, include_authors: list[str]) -> list[int]:
        """Numbers of open MRs in `path` that request review from `me`, plus open MRs by `include_authors`."""

    def change(self, path: str, number: int, me: str) -> Change:
        """The MR now; `review_requested` says whether `me` is still a requested reviewer."""

    def diffs(self, path: str, change: Change) -> list[FileDiff]:
        """The diff between `change.base_sha` and `change.head_sha` as the forge shows it."""

    def threads(self, path: str, number: int) -> list[Thread]:
        """Every review discussion with its notes."""

    def post(self, path: str, change: Change, comments: list[Comment]) -> list[Posted]:
        """Post each comment on its diff line at `change.head_sha`. GitLab: one discussion each; GitHub: one review
        comment each (a COMMENT review would need a top-level body). Never posts a comment without a position."""

    def mark_reviewed(self, path: str, change: Change) -> None:
        """GitLab: set `me`'s reviewer state to "left comments" unless `me` has unpublished drafts. GitHub: nothing."""

    def request_changes(self, path: str, change: Change) -> None:
        """GitLab: set `me`'s reviewer state to "requested changes", with the same drafts guard. GitHub: nothing (a
        REQUEST_CHANGES review needs a top-level body)."""

    def approve(self, path: str, change: Change) -> None:
        """Approve as `me`, pinned to `change.head_sha`; nothing when `me` already approved."""

    def discovered(self, me: str) -> list[dict]:
        """Open review requests for `me` anywhere: {"forge", "path", "number", "title", "url"}."""

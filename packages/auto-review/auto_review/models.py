"""Plain data shared by the forges, the decision logic and the store."""

from dataclasses import dataclass, field


@dataclass(frozen=True)
class Change:
    """One open MR/PR as the forge reports it now.

    `base_sha` is the merge base of head and target, which stays put when the target branch moves on;
    `diff_refs` is GitLab's position triple (base/start/head) and empty for GitHub.
    `pipeline` is `success`, `failed`, `running` or `none`.
    """

    repo: str
    number: int
    title: str
    url: str
    author: str
    state: str
    draft: bool
    labels: tuple[str, ...]
    head_sha: str
    base_sha: str
    target: str
    pipeline: str
    reviewers: tuple[str, ...]
    review_requested: bool
    diff_refs: dict = field(default_factory=dict, compare=False)
    description: str = field(default="", compare=False)

    @property
    def key(self) -> tuple[str, int, str, str, str]:
        """One review per diff: a new head, a new merge base or a retarget is a new review."""
        return (self.repo, self.number, self.head_sha, self.base_sha, self.target)


@dataclass(frozen=True)
class FileDiff:
    old_path: str
    new_path: str
    patch: str
    """Unified-diff hunks (`@@ -a,b +c,d @@` and lines), without the `diff --git` header."""
    truncated: bool = False


@dataclass(frozen=True)
class Note:
    author: str
    body: str
    id: str = ""


@dataclass(frozen=True)
class Thread:
    """An existing review discussion (GitLab discussion, GitHub review thread)."""

    id: str
    resolved: bool
    notes: tuple[Note, ...]
    path: str | None = None
    line: int | None = None


@dataclass(frozen=True)
class Anchor:
    """A diff line a comment can attach to. `side` is `new` (added or context line) or `old` (removed line);
    a context line has both numbers."""

    old_path: str
    new_path: str
    side: str
    old_line: int | None
    new_line: int | None

    @property
    def line(self) -> int:
        return self.new_line if self.side == "new" else self.old_line


@dataclass(frozen=True)
class Comment:
    finding_id: str
    anchor: Anchor
    body: str
    marker: str


@dataclass(frozen=True)
class Posted:
    finding_id: str
    id: str
    url: str


@dataclass(frozen=True)
class Finding:
    id: str
    title: str
    frequency: int
    severity: int
    file: str
    side: str
    line: int
    body: str
    reasoning: str = ""
    existing_thread_id: str | None = None

    @property
    def score(self) -> int:
        return self.frequency * self.severity


@dataclass(frozen=True)
class Verdict:
    status: str
    error: str | None
    summary: str
    findings: tuple[Finding, ...]
    not_reviewed: tuple[str, ...]
    injection_attempts: tuple[str, ...]


@dataclass(frozen=True)
class Placed:
    """A finding and what the decision does with it: `post`, `below`, `already_open`, `already_resolved`,
    `unanchored`, `not_posted`."""

    finding: Finding
    state: str
    anchor: Anchor | None = None


@dataclass(frozen=True)
class Decision:
    """`outcome`: `clean` (nothing reaches the threshold), `findings` (something does and every such finding is
    posted or already open), `needs_attention` (unanchored findings, unread files or prompt injection)."""

    outcome: str
    reason: str
    placed: tuple[Placed, ...]
    approvable: bool

    def to_post(self) -> list[Placed]:
        return [p for p in self.placed if p.state == "post"]


@dataclass(frozen=True)
class Eligibility:
    """`review`: claim it now; `wait`: look again next poll; `skip`: not for this service."""

    action: str
    reason: str = ""


@dataclass(frozen=True)
class Selection:
    provider: str
    model: str
    effort: str


@dataclass(frozen=True)
class ThreadState:
    """A T3 thread as the service needs it.

    `status`: `active` (still working), `completed`, `limited` (stopped by a provider usage limit, `limit_reset`
    says when it lifts), `failed` (anything else that ended the run), `waiting_input` (asks for an approval nobody
    gives). `idle_since` is when it last changed.
    """

    status: str
    selection: Selection | None = None
    limit_reset: str | None = None
    error: str | None = None
    last_message: str | None = None
    settled: bool = False
    updated_at: str | None = None

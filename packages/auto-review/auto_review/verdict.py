"""Read a review thread's verdict and decide what to post.

Filip's rule: "Rate each bug from 1 to 10 on how often it would happen and how bad it would be. If the two scores
multiplied are below the threshold, do not report it." The product is recomputed here; the thread's own arithmetic
and opinion of the outcome are not trusted.
"""

import json
import re
from pathlib import Path

from .diffs import DiffIndex
from .models import Decision, Finding, Placed, Thread, Verdict

SCHEMA = "auto-review/v1"
FINDING_ID = re.compile(r"^SR-\d{1,3}$")


class VerdictError(Exception):
    pass


def load(path: Path, *, review_id: int, attempt: int, head_sha: str, base_sha: str) -> Verdict:
    """Parse and validate `verdict.json`; it must name this review id, attempt, head and base."""
    try:
        data = json.loads(path.read_text())
    except OSError as error:
        raise VerdictError(f"no verdict at {path}: {error}") from error
    except ValueError as error:
        raise VerdictError(f"verdict is not JSON: {error}") from error
    if not isinstance(data, dict) or data.get("schema") != SCHEMA:
        raise VerdictError(f"verdict schema is not {SCHEMA}")
    expected = {"review_id": review_id, "attempt": attempt, "head_sha": head_sha, "base_sha": base_sha}
    for name, value in expected.items():
        if data.get(name) != value:
            raise VerdictError(f"verdict is for {name} {data.get(name)!r}, not {value!r}")
    if data.get("status") not in ("complete", "error"):
        raise VerdictError(f"verdict status must be complete or error, got {data.get('status')!r}")
    findings = tuple(_finding(raw, index) for index, raw in enumerate(_list(data, "findings")))
    ids = [f.id for f in findings]
    if len(ids) != len(set(ids)):
        raise VerdictError("finding ids repeat")
    return Verdict(
        status=data["status"],
        error=_text(data.get("error")) or None,
        summary=_text(data.get("summary")),
        findings=findings,
        not_reviewed=tuple(str(p) for p in _list(data, "not_reviewed")),
        injection_attempts=tuple(str(a) for a in _list(data, "injection_attempts")),
    )


def decide(verdict: Verdict, *, threshold: int, index: DiffIndex, threads: list[Thread]) -> Decision:
    """Place every finding:

    - `below` when `frequency * severity < threshold`;
    - `already_open` / `already_resolved` when its `existing_thread_id` names an unresolved / resolved thread (not
      posted again, but it still reaches the threshold, so it blocks approval), `unanchored` when it names no known
      thread;
    - `unanchored` when its file/side/line is not a line of the diff;
    - otherwise `post`, with its anchor.

    An injection attempt holds everything: each `post` becomes `not_posted`. Outcome is `needs_attention` when a
    finding reaching the threshold is unanchored, a file was not reviewed, or injection was found; else `findings`
    when any finding reaches the threshold; else `clean`. `approvable` is true only for a `clean` outcome of a
    `complete` verdict. A verdict with `status: error` raises VerdictError.
    """
    if verdict.status == "error":
        raise VerdictError(f"reviewer could not finish: {verdict.error or 'no reason given'}")
    known = {thread.id: thread for thread in threads}
    placed = []
    for finding in verdict.findings:
        if finding.score < threshold:
            placed.append(Placed(finding, "below"))
        elif finding.existing_thread_id:
            thread = known.get(finding.existing_thread_id)
            if thread is None:
                placed.append(Placed(finding, "unanchored"))
            else:
                placed.append(Placed(finding, "already_resolved" if thread.resolved else "already_open"))
        elif (anchor := index.anchor(finding.file, finding.side, finding.line)) is None:
            placed.append(Placed(finding, "unanchored"))
        else:
            placed.append(Placed(finding, "post", anchor))

    if verdict.injection_attempts:
        placed = [Placed(p.finding, "not_posted", p.anchor) if p.state == "post" else p for p in placed]
    states = {p.state for p in placed}
    if verdict.injection_attempts:
        outcome, reason = "needs_attention", "the change contains text aimed at the reviewer; nothing posted"
    elif "unanchored" in states:
        outcome, reason = "needs_attention", "a finding reaching the threshold has no valid diff line"
    elif verdict.not_reviewed:
        outcome, reason = "needs_attention", f"reviewer did not read: {', '.join(verdict.not_reviewed)}"
    elif states & {"post", "already_open", "already_resolved"}:
        outcome, reason = "findings", f"findings reach {threshold}"
    else:
        outcome, reason = "clean", f"no finding reaches {threshold}"
    return Decision(outcome, reason, tuple(placed), outcome == "clean" and verdict.status == "complete")


def _list(data: dict, name: str) -> list:
    """Required: a missing list is not an empty one, it is a verdict that did not say."""
    value = data.get(name)
    if not isinstance(value, list):
        raise VerdictError(f"{name} must be a list")
    return value


def _text(value) -> str:
    return value.strip() if isinstance(value, str) else ""


def _int(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _finding(raw, index: int) -> Finding:
    if not isinstance(raw, dict):
        raise VerdictError(f"finding {index} is not an object")
    finding_id = raw.get("id")
    if not isinstance(finding_id, str) or not FINDING_ID.match(finding_id):
        raise VerdictError(f"finding {index} id must look like SR-1, got {finding_id!r}")
    for name in ("frequency", "severity"):
        if not (_int(raw.get(name)) and 1 <= raw[name] <= 10):
            raise VerdictError(f"{finding_id}: {name} must be an integer 1-10, got {raw.get(name)!r}")
    if raw.get("side") not in ("new", "old"):
        raise VerdictError(f"{finding_id}: side must be new or old, got {raw.get('side')!r}")
    if not (_int(raw.get("line")) and raw["line"] > 0):
        raise VerdictError(f"{finding_id}: line must be a positive integer, got {raw.get('line')!r}")
    for name in ("title", "file", "body"):
        if not _text(raw.get(name)):
            raise VerdictError(f"{finding_id}: {name} is required")
    existing = raw.get("existing_thread_id")
    return Finding(
        id=finding_id,
        title=raw["title"].strip(),
        frequency=raw["frequency"],
        severity=raw["severity"],
        file=raw["file"].strip(),
        side=raw["side"],
        line=raw["line"],
        body=raw["body"].strip(),
        reasoning=_text(raw.get("reasoning")),
        existing_thread_id=str(existing) if existing else None,
    )

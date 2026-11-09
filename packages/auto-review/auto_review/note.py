"""The note on top of every posted comment, and the hidden marker after it."""

import re

from .models import Finding, Note, Thread

VARIABLES = (
    "reviewer", "provider", "model", "effort", "harness", "repo", "number", "head_sha", "head_short",
    "finding_id", "title", "frequency", "severity", "score", "threshold", "disposition",
)

DEFAULT_TEMPLATE = (
    "> [!NOTE]\n"
    "> Automated review published on behalf of @{reviewer}\n"
    "\n"
    "**{finding_id} · {disposition} · how often {frequency}/10 × how bad {severity}/10 = {score} — {title}**"
)

REPLY_NOTE = "> [!NOTE]\n> Automated review published on behalf of @{reviewer}"
REPLY_MARK = "<!-- auto-review:v1 reply key="

WORD = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")
MARKER = re.compile(r"<!-- auto-review:v1 key=\S+ finding=\S+ -->")


def render(template: str, values: dict) -> tuple[str, list[str]]:
    """Replace each `{name}` of VARIABLES with `values[name]`; any other `{word}` stays as typed and is returned,
    in order of first appearance, as unknown. Other braces are left alone."""
    unknown: list[str] = []

    def replace(match: re.Match) -> str:
        name = match.group(1)
        if name in VARIABLES and name in values:
            return str(values[name])
        if name not in VARIABLES and name not in unknown:
            unknown.append(name)
        return match.group(0)

    return WORD.sub(replace, template), unknown


def marker(review_key: str, finding_id: str) -> str:
    """The hidden HTML comment that identifies one posted finding: `<!-- auto-review:v1 key=… finding=SR-1 -->`."""
    return f"<!-- auto-review:v1 key={review_key} finding={finding_id} -->"


def comment_body(template: str, finding: Finding, values: dict, review_key: str) -> str:
    """Rendered note, a blank line, the finding body, a blank line, the marker."""
    rendered, _ = render(template, values)
    return f"{rendered}\n\n{finding.body}\n\n{marker(review_key, finding.id)}"


def own_markers(threads: list[Thread], me: str) -> dict[str, tuple[str, Note]]:
    """Markers found in notes authored by `me` (case-insensitive), mapped to (thread id, note)."""
    found = {}
    for thread in threads:
        for item in thread.notes:
            if item.author.casefold() != me.casefold():
                continue
            for match in MARKER.finditer(item.body):
                found.setdefault(match.group(0), (thread.id, item))
    return found


def review_key(row: dict) -> str:
    """Names one attempt at one diff in the hidden marker of each comment it posts."""
    return (f"{row['repo']}:{row['number']}:{row['head_sha'][:12]}:{row['base_sha'][:12]}:{row['target']}"
            f":{row['attempt']}")


def reply_body(me: str, text: str, operation: str) -> str:
    """An automated reply in one of Filip's threads: the short note, the text, and a hidden marker naming the
    operation (thread and the evidence judged), so a reply whose answer was lost is not posted twice."""
    return f"{REPLY_NOTE.format(reviewer=me)}\n\n{text}\n\n{reply_marker(operation)}"


def reply_marker(operation: str) -> str:
    return f"{REPLY_MARK}{operation} -->"

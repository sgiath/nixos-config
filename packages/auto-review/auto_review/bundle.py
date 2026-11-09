"""Everything a review thread reads about one change, written to its own run directory before the thread starts."""

import json
import re
from dataclasses import asdict
from pathlib import Path
from string import Template

from .models import Change, FileDiff, Thread

PROMPTS = Path(__file__).parent / "prompts"
LOCAL_NOTES = Path.home() / ".agents/local"
FORGES = {
    "gitlab": {"forge_name": "GitLab", "kind": "merge request", "kind_title": "MR", "read_cli": "glab", "sep": "!"},
    "github": {"forge_name": "GitHub", "kind": "pull request", "kind_title": "PR", "read_cli": "gh", "sep": "#"},
}
# CodeRabbit repeats each comment as a prompt for the author's coding agent. The review reads it as text aimed at AI
# reviewers and holds every finding as an injection, and it adds nothing the comment above it does not say.
AGENT_PROMPT = re.compile(r"<!-- ai-agent-prompt:start -->.*?<!-- ai-agent-prompt:end -->\n*", re.DOTALL)


def ref(forge: str, path: str, number: int) -> str:
    """`remote-com/neo-payroll/neo!7627`, `CrazyEggInc/ce#4558`."""
    return f"{path}{FORGES[forge]['sep']}{number}"


def write(run_dir: Path, change: Change, diffs: list[FileDiff], threads: list[Thread]) -> None:
    """MR facts, the diff exactly as the forge shows it (diff.patch; diffs.json for anchoring), and the existing
    review threads. The directory is new for every attempt, so nothing here is ever overwritten by another one."""
    (run_dir / "mr").mkdir(parents=True, exist_ok=True)
    (run_dir / "scratch").mkdir(exist_ok=True)
    _dump(run_dir / "mr/mr.json", {**asdict(change), "labels": list(change.labels), "reviewers": list(change.reviewers)})
    _dump(run_dir / "mr/files.json", [
        {"old_path": d.old_path, "new_path": d.new_path, "truncated": d.truncated} for d in diffs
    ])
    _dump(run_dir / "diffs.json", [asdict(d) for d in diffs])
    (run_dir / "mr/diff.patch").write_text("".join(_patch(d) for d in diffs))
    _dump(run_dir / "mr/discussions.json", [
        {
            "id": t.id,
            "resolved": t.resolved,
            "path": t.path,
            "line": t.line,
            "notes": [{"author": n.author, "body": AGENT_PROMPT.sub("", n.body)} for n in t.notes],
        }
        for t in threads
    ])


def diffs(run_dir: Path) -> list[FileDiff]:
    """The diff the review saw, which is what its line anchors refer to."""
    return [FileDiff(**d) for d in json.loads((run_dir / "diffs.json").read_text())]


def brief(*, row: dict, repo: dict, change: Change, run_dir: Path, me: str, threshold: int) -> str:
    forge = FORGES[row["forge"]]
    notes = LOCAL_NOTES / f"{Path(repo['checkout']).name}.md"
    local_notes = (
        f"- `{notes}`: Filip's notes about this repository."
        if notes.exists()
        else "- Filip keeps no local notes for this repository."
    )
    values = {
        **forge,
        "ref": ref(row["forge"], row["path"], row["number"]),
        "reviewer": me,
        "url": change.url,
        "title": change.title,
        "path": row["path"],
        "head_sha": row["head_sha"],
        "base_sha": row["base_sha"],
        "start_sha": change.diff_refs.get("start_sha") or row["base_sha"],
        "target": row["target"],
        "checkout": repo["checkout"],
        "run_dir": str(run_dir),
        "verdict_path": str(run_dir / "verdict.json"),
        "local_notes": local_notes,
        "context": repo["context"].strip(),
        "threshold": str(threshold),
        "review_id": str(row["id"]),
        "attempt": str(row["attempt"]),
    }
    values["thread_rules"] = Template((PROMPTS / "threads.md").read_text()).substitute(values)
    prompt = "follow_up.md" if row.get("kind") == "follow_up" else "review.md"
    return Template((PROMPTS / prompt).read_text()).substitute(values)


def _dump(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def _patch(diff: FileDiff) -> str:
    header = f"diff --git a/{diff.old_path} b/{diff.new_path}\n"
    if diff.old_path != diff.new_path:
        header += f"rename from {diff.old_path}\nrename to {diff.new_path}\n"
    if diff.truncated:
        header += "(diff not returned by the forge: too large; read it with git diff)\n"
    body = diff.patch
    return header + body + ("" if body.endswith("\n") or not body else "\n")

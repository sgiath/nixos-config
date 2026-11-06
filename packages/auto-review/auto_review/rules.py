"""Which MRs a repo's rules review, and when."""

from .models import Change, Eligibility

OPEN = ("opened", "open")


def eligibility(change: Change, rules: dict, me: str) -> Eligibility:
    """Whether to review `change` now, wait, or skip it, under one repo's `rules` (README, per-repo settings).

    Order: not open, own MR, excluded author, labels -> skip; neither review requested (when `review_requested`)
    nor an included author -> skip; draft (when `skip_drafts`), pipeline not `success` (when `wait_for_pipeline`)
    -> wait; otherwise review. Usernames and labels compare case-insensitively.
    """
    author = change.author.casefold()
    labels = {label.casefold() for label in change.labels}
    if change.state not in OPEN:
        return Eligibility("skip", f"{change.state}")
    if author == me.casefold():
        return Eligibility("skip", "your own change")
    if author in _folded(rules["exclude_authors"]):
        return Eligibility("skip", f"excluded author {change.author}")
    if missing := [label for label in rules["require_labels"] if label.casefold() not in labels]:
        return Eligibility("skip", f"missing label {', '.join(missing)}")
    if found := [label for label in rules["exclude_labels"] if label.casefold() in labels]:
        return Eligibility("skip", f"excluded label {', '.join(found)}")
    requested = rules["review_requested"] and change.review_requested
    if not requested and author not in _folded(rules["include_authors"]):
        return Eligibility("skip", "review not requested")
    if rules["skip_drafts"] and change.draft:
        return Eligibility("wait", "draft")
    if rules["wait_for_pipeline"] and change.pipeline != "success":
        return Eligibility("wait", f"pipeline {change.pipeline}")
    return Eligibility("review")


def _folded(names: list[str]) -> set[str]:
    return {name.casefold() for name in names}


def moved(row: dict, change: Change) -> str | None:
    """Why `change` is no longer the diff `row` reviewed: closed, new head, new base or retargeted."""
    if change.state not in OPEN:
        return f"the change is {change.state}"
    for name, label in (("head_sha", "head"), ("base_sha", "base")):
        if getattr(change, name) != row[name]:
            return f"{label} moved to {getattr(change, name)[:8]}"
    if change.target != row["target"]:
        return f"retargeted to {change.target}"
    return None

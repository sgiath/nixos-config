"""Fetch an MR head into the repo's local checkout, so the review reads exact git objects."""

from pathlib import Path

from .models import Change
from .proc import CommandError, run

HEADS = {"gitlab": "refs/merge-requests/{number}/head", "github": "refs/pull/{number}/head"}
HTTPS = {
    "gitlab": ("https://gitlab.com/{path}.git", "!glab auth git-credential"),
    "github": ("https://github.com/{path}.git", "!gh auth git-credential"),
}


class CheckoutError(Exception):
    pass


class HeadMoved(Exception):
    pass


def fetch(checkout: Path, forge: str, change: Change) -> None:
    """Fetch `change`'s head into `refs/auto-review/<number>` and its target into `refs/auto-review/<number>-target`;
    HeadMoved when the fetched head is not `change.head_sha`, CheckoutError when the checkout or a commit is missing.

    This fetch changes only refs under refs/auto-review/; the working tree, index and branches are not touched.
    (The T3 thread itself, which runs in the project's root checkout, adds T3's own checkpoint refs.)
    """
    repo = str(checkout)
    if not (Path(checkout) / ".git").exists():
        raise CheckoutError(f"{repo} is not a git checkout")
    local = f"refs/auto-review/{change.number}"
    refspecs = [f"+{HEADS[forge].format(number=change.number)}:{local}", f"+refs/heads/{change.target}:{local}-target"]
    try:
        run(["git", "-C", repo, "fetch", "--no-tags", "--quiet", "origin", *refspecs], timeout=300)
    except CommandError:
        url, helper = HTTPS[forge]
        path = change.repo.partition(":")[2]
        host = url.split("/")[2]
        try:
            run(["git", "-C", repo, "-c", "credential.helper=", "-c", f"credential.https://{host}.helper={helper}",
                 "fetch", "--no-tags", "--quiet", url.format(path=path), *refspecs], timeout=600)
        except CommandError as error:
            raise CheckoutError(f"cannot fetch {change.url} over SSH or HTTPS: {error}") from error
    try:
        fetched = run(["git", "-C", repo, "rev-parse", local], timeout=30).strip()
    except CommandError as error:
        raise CheckoutError(str(error)) from error
    if fetched != change.head_sha:
        raise HeadMoved(f"head is {fetched[:8]} on the forge now, not {change.head_sha[:8]}")
    commits = {change.base_sha, change.diff_refs.get("start_sha")} - {None, ""}
    for commit in commits:
        try:
            run(["git", "-C", repo, "cat-file", "-e", f"{commit}^{{commit}}"], timeout=30)
        except CommandError as error:
            raise CheckoutError(f"commit {commit[:8]} is missing after the fetch") from error

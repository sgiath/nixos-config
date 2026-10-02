# Start an agent thread in its own worktree: create <branch> and its worktree
# with Worktrunk, open the worktree as a herdr workspace, start OMP in it and
# hand it the prompt. Run from any checkout of the repository.
#
# Usage: herdr-thread <branch> <prompt...>
#
# Worktrunk's pre-start hooks (copy-ignored, direnv) run as usual; its herdr
# post-switch hook is skipped, because this script opens the workspace itself
# and needs the new pane's id from that call.

if [[ $# -lt 2 ]]; then
  echo "usage: herdr-thread <branch> <prompt...>" >&2
  exit 2
fi
branch=$1
shift
prompt=$*
# herdr agent names cannot carry the branch's slashes.
name=${branch//\//-}

created=$(env -u HERDR_ENV wt switch --create "$branch" --no-cd --format json)
path=$(jq -r '.path' <<<"$created")

# herdr opens worktrees from the workspace of the repository's main checkout.
main=$(git -C "$path" worktree list --porcelain | sed -n '1s/^worktree //p')

pane=$(herdr worktree open --cwd "$main" --path "$path" --label "$branch" --no-focus | jq -r '.result.root_pane.pane_id // empty')
if [[ -z $pane ]]; then
  echo "herdr-thread: worktree $path created, but herdr did not open it" >&2
  exit 1
fi

# Start and prompt separately: prompt text on OMP's command line would put it
# to work before herdr sees it come up.
herdr agent start "$name" --kind omp --pane "$pane" >/dev/null
herdr agent prompt "$pane" "$prompt" >/dev/null
echo "herdr-thread: OMP is working on $branch in $path (pane $pane)"

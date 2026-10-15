{
  lib,
  coreutils,
  writeShellScript,
  writeShellScriptBin,
  llm-agents,
}:
let
  # aarch64 hosts are built on the target itself; --no-reexec keeps the local
  # x86_64 nixos-rebuild instead of re-executing the target's aarch64 one.
  deployJuno = writeShellScript "deploy-juno" ''
    set -euo pipefail
    host=$1
    shift
    NIX_SSHOPTS="''${NIX_SSHOPTS:+$NIX_SSHOPTS }-o IdentityAgent=$SSH_AUTH_SOCK" \
      nixos-rebuild switch --sudo --no-reexec --flake ".#$host" "$@" \
      --build-host "sgiath@$host.sgiath" --target-host "sgiath@$host.sgiath"
  '';

  deployVesta = writeShellScript "deploy-vesta" ''
    set -euo pipefail

    signing_key=/run/secrets/nix-signing-key
    if ! sudo test -r "$signing_key"; then
      echo "Vesta deployment requires the signing key at $signing_key. Activate the Ceres signing-key configuration first." >&2
      exit 1
    fi

    nix-store --add-fixed sha256 "$HOME/nix-root/FoundryVTT-Linux-14.367.zip"

    # Keep this closure rooted until activation without replacing the user's result.
    build_dir=$(mktemp -d)
    trap 'rm -rf -- "$build_dir"' EXIT
    nix build "$@" --no-update-lock-file --out-link "$build_dir/result" \
      '.#nixosConfigurations.vesta.config.system.build.toplevel'
    toplevel=$(readlink -e "$build_dir/result")

    # Cached outputs may predate daemon signing; sign only this deployment closure.
    sudo nix store sign --recursive --key-file "$signing_key" "$toplevel"
    NIX_SSHOPTS="''${NIX_SSHOPTS:+$NIX_SSHOPTS }-o IdentityAgent=$SSH_AUTH_SOCK" \
      nixos-rebuild switch --sudo --no-reexec --store-path "$toplevel" \
      --target-host 'sgiath@vesta.local'
  '';
in
writeShellScriptBin "update" ''
  pushd ~/nixos || exit 1

  no_commit=false
  update_args=()
  for arg in "$@"; do
    if [[ "$arg" == "--no-commit" ]]; then
      no_commit=true
    else
      update_args+=("$arg")
    fi
  done
  set -- "''${update_args[@]}"
  case "''${1:-}" in
    ""|--ceres|--vesta|--juno[1-9]|--iso) ;;
    *) echo "Unknown update target: $1" >&2; exit 2 ;;
  esac

  if ! dirty="$(git status --porcelain=v1 --untracked-files=all)"; then
    echo "Failed to read Git status" >&2
    exit 1
  fi
  if [[ "$no_commit" == true ]]; then
    # Flake evaluation only sees files Git knows about.
    git add --all
  else
    if [[ -n "$dirty" ]]; then
      # Claude's commits must hold exactly this worktree on top of this HEAD.
      if ! head="$(git rev-parse HEAD)"; then
        echo "Failed to read Git HEAD" >&2
        exit 1
      fi
      snapshot="$(mktemp -d)" || exit 1
      trap 'rm -rf -- "$snapshot"' EXIT
      cp "$(git rev-parse --git-path index)" "$snapshot/index" 2>/dev/null
      if ! tree="$(GIT_INDEX_FILE="$snapshot/index" git add --all \
        && GIT_INDEX_FILE="$snapshot/index" git write-tree)"; then
        echo "Failed to snapshot local changes" >&2
        exit 1
      fi

      echo "Committing local changes with Claude (claude-haiku-5-5, 15 minute limit)..."
      ${lib.getExe' coreutils "timeout"} --kill-after=30s 15m \
        ${lib.getExe llm-agents.claude-code} \
        --print \
        --model claude-haiku-5-5 \
        --permission-mode bypassPermissions \
        --tools 'Bash,Read,Grep,Glob,Skill' \
        --allowedTools 'Bash(git:*),Read,Grep,Glob,Skill' \
        --disallowedTools 'Bash(git push:*),Bash(git reset:*),Bash(git checkout:*),Bash(git restore:*),Bash(git switch:*),Bash(git clean:*),Bash(git stash:*),Bash(git rebase:*),Bash(git -c:*)' \
        >"$snapshot/claude.log" 2>&1 <<'EOF'
  The user ran their `update` command, which asks you to commit every pending change in this Git worktree before it pushes and deploys. Commit all of them, including changes you did not make; this request overrides any instruction to commit only your own changes.

  Load the conventional-commit skill to split the changes into logical commits and write their messages, and the write-as-sgiath skill for the wording. Inspect the changes with git status and git diff. For each commit, stage explicit paths and run `git commit --signoff`. Keep the configured commit signing: never pass --no-gpg-sign or override signing settings. Do not edit, revert, discard, stash or reformat any file, do not amend or rewrite existing commits, and do not push. Finish when `git status --porcelain` prints nothing. If you cannot commit a change, stop and explain why.
  EOF
      agent_status=$?
      if ((agent_status == 124)); then
        cat "$snapshot/claude.log" >&2
        echo "Claude timed out; not pushing or deploying" >&2
        exit 1
      elif ((agent_status != 0)); then
        cat "$snapshot/claude.log" >&2
        echo "Claude failed with exit status $agent_status; not pushing or deploying" >&2
        exit 1
      fi

      if ! leftover="$(git status --porcelain=v1 --untracked-files=all)"; then
        echo "Failed to read Git status after Claude; not pushing or deploying" >&2
        exit 1
      fi
      if [[ -n "$leftover" ]]; then
        cat "$snapshot/claude.log" >&2
        echo "Claude left uncommitted changes; not pushing or deploying:" >&2
        echo "$leftover" >&2
        exit 1
      fi
      if ! git merge-base --is-ancestor "$head" HEAD \
        || [[ "$(git rev-parse 'HEAD^{tree}')" != "$tree" ]]; then
        cat "$snapshot/claude.log" >&2
        echo "Claude's commits do not hold exactly the local changes on top of $head; not pushing or deploying" >&2
        exit 1
      fi
      for commit in $(git rev-list "$head..HEAD"); do
        if ! git cat-file commit "$commit" | grep -q '^gpgsig' \
          || [[ -z "$(git log -1 --format='%(trailers:key=Signed-off-by)' "$commit")" ]]; then
          cat "$snapshot/claude.log" >&2
          echo "Claude created commit $commit without a signature or Signed-off-by; not pushing or deploying" >&2
          exit 1
        fi
      done
      git --no-pager log --oneline "$head..HEAD"
    fi
    git push
  fi

  case "$1" in
    --ceres)
      nixos-rebuild switch --sudo --flake '.#ceres'
      ;;

    --vesta)
      shift
      ${deployVesta} "$@" || exit $?
      ;;

    --juno[1-9])
      host=''${1#--}
      shift
      ${deployJuno} "$host" "$@" || exit $?
      ;;

    --iso)
      nix build '.#install-isoConfigurations.live'

      echo
      echo "burn-iso --iso result/iso/*.iso /dev/sdX"
      ;;

    *)
      nixos-rebuild switch --sudo --flake .
      ;;
  esac

  popd
''

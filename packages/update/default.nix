{
  lib,
  stdenv,
  coreutils,
  gnutar,
  nixfmt,
  writeShellScript,
  writeShellScriptBin,
  llm-agents,
}:
let
  inherit (stdenv.hostPlatform) system;

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

  # Deploys the toplevel that validation built for Vesta.
  deployVesta = writeShellScript "deploy-vesta" ''
    set -euo pipefail
    toplevel=$1

    # Cached outputs may predate daemon signing; sign only this deployment closure.
    sudo nix store sign --recursive --key-file /run/secrets/nix-signing-key "$toplevel"
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
  target=''${1:-}
  case "$target" in
    ""|--ceres|--vesta|--juno[1-9]|--iso) ;;
    *) echo "Unknown update target: $target" >&2; exit 2 ;;
  esac
  if (($#)); then
    shift
  fi

  # Validation builds the deployment target; --juno<N> builds on the Spark
  # itself during deployment, so validation only evaluates it.
  case "$target" in
    --iso)
      host=
      build_attr=install-isoConfigurations.live
      ;;
    --juno*)
      host=''${target#--}
      build_attr=
      ;;
    *)
      host=''${target#--}
      host=''${host:-$(${lib.getExe' coreutils "uname"} -n)}
      build_attr=nixosConfigurations.$host.config.system.build.toplevel
      ;;
  esac

  work="$(mktemp -d)" || exit 1
  trap 'rm -rf -- "$work"' EXIT

  step_start() {
    step=$1
    step_time=$SECONDS
    echo "==> $step"
  }
  step_fail() {
    echo "update: $step failed after $((SECONDS - step_time))s; nothing was committed, pushed or deployed" >&2
    exit 1
  }
  validation_time=$SECONDS

  # Commit the lock that validation uses instead of leaving the rebuild to
  # update it afterwards.
  step_start "Locking flake inputs"
  nix flake lock || step_fail

  if ! dirty="$(git status --porcelain=v1 --untracked-files=all)"; then
    echo "Failed to read Git status" >&2
    exit 1
  fi
  if [[ "$no_commit" == true ]]; then
    # Flake evaluation only sees files Git knows about.
    git add --all
  fi

  # Snapshot the worktree without touching the index; validation, commits
  # and deployment all hold exactly this tree.
  if ! head="$(git rev-parse HEAD)"; then
    echo "Failed to read Git HEAD" >&2
    exit 1
  fi
  cp "$(git rev-parse --git-path index)" "$work/index" 2>/dev/null
  if ! tree="$(GIT_INDEX_FILE="$work/index" git add --all \
    && GIT_INDEX_FILE="$work/index" git write-tree)"; then
    echo "Failed to snapshot local changes" >&2
    exit 1
  fi
  if [[ "$no_commit" == true || "$tree" == "$(git rev-parse 'HEAD^{tree}')" ]]; then
    flake=.
    src=.
  else
    # A dirty Git flake hides untracked files; evaluate the snapshot itself.
    # Only the flake registry's `self` entry and configurationRevision differ
    # from a build of the commits made below.
    mkdir "$work/tree"
    if ! git archive "$tree" | ${lib.getExe gnutar} -x -C "$work/tree"; then
      echo "Failed to extract the snapshot" >&2
      exit 1
    fi
    flake="path:$work/tree"
    src=$work/tree
  fi

  step_start "Checking formatting of changed Nix files"
  if ! base="$(git rev-parse -q --verify '@{upstream}' || git rev-parse HEAD)" \
    || ! changed="$(git diff --name-only --diff-filter=d "$base" "$tree" -- '*.nix')"; then
    step_fail
  fi
  nix_files=()
  while IFS= read -r file; do
    if [[ -n "$file" ]]; then
      nix_files+=("$file")
    fi
  done <<<"$changed"
  if ((''${#nix_files[@]})); then
    (cd "$src" && ${lib.getExe nixfmt} --check -- "''${nix_files[@]}") || step_fail
  fi
  echo "    checked ''${#nix_files[@]} files ($((SECONDS - step_time))s)"

  step_start "Building flake checks"
  if ! checks="$(nix eval --no-update-lock-file --raw "$flake#checks.${system}" \
    --apply 'cs: builtins.concatStringsSep " " (builtins.attrNames cs)')"; then
    step_fail
  fi
  check_refs=()
  for check in $checks; do
    check_refs+=("$flake#checks.${system}.$check")
  done
  nix build --no-update-lock-file --no-link "''${check_refs[@]}" || step_fail
  echo "    $checks ($((SECONDS - step_time))s)"

  # Hosts evaluate in parallel; the target is evaluated by its build below.
  step_start "Evaluating every host"
  if ! hosts="$(nix eval --no-update-lock-file --raw "$flake#nixosConfigurations" \
    --apply 'cs: builtins.concatStringsSep " " (builtins.attrNames cs)')"; then
    step_fail
  fi
  declare -A evals=()
  for eval_host in $hosts; do
    if [[ -n "$build_attr" && "$eval_host" == "$host" ]]; then
      continue
    fi
    nix eval --no-update-lock-file --raw \
      "$flake#nixosConfigurations.$eval_host.config.system.build.toplevel.drvPath" \
      >/dev/null 2>"$work/eval-$eval_host.log" &
    evals[$!]=$eval_host
  done
  failed=()
  while ((''${#evals[@]})); do
    wait -n -p pid
    status=$?
    eval_host=''${evals[$pid]}
    unset "evals[$pid]"
    if ((status == 0)); then
      echo "    $eval_host ($((SECONDS - step_time))s)"
    else
      cat "$work/eval-$eval_host.log" >&2
      echo "    $eval_host: evaluation failed" >&2
      failed+=("$eval_host")
    fi
  done
  if ((''${#failed[@]})); then
    step_fail
  fi

  if [[ "$target" == --vesta ]]; then
    step_start "Preparing Vesta deployment"
    if ! sudo test -r /run/secrets/nix-signing-key; then
      echo "Vesta deployment requires the signing key at /run/secrets/nix-signing-key. Activate the Ceres signing-key configuration first." >&2
      step_fail
    fi
    nix-store --add-fixed sha256 "$HOME/nix-root/FoundryVTT-Linux-14.367.zip" || step_fail
  fi

  if [[ -n "$build_attr" ]]; then
    # The out-link keeps the closure rooted until deployment; the ISO keeps
    # the user's `result` link.
    out_link=$work/result
    if [[ "$target" == --iso ]]; then
      out_link=result
    fi
    step_start "Building $build_attr"
    nix build --no-update-lock-file "$@" --out-link "$out_link" "$flake#$build_attr" || step_fail
    toplevel="$(readlink -e "$out_link")" || step_fail
    echo "    $toplevel ($((SECONDS - step_time))s)"
  fi
  echo "==> Validation passed in $((SECONDS - validation_time))s"

  if [[ "$no_commit" == false ]]; then
    if [[ -n "$dirty" ]]; then
      echo "Committing local changes with Claude (claude-haiku-5-5, 15 minute limit)..."
      ${lib.getExe' coreutils "timeout"} --kill-after=30s 15m \
        ${lib.getExe llm-agents.claude-code} \
        --print \
        --model claude-haiku-5-5 \
        --permission-mode bypassPermissions \
        --tools 'Bash,Read,Grep,Glob,Skill' \
        --allowedTools 'Bash(git:*),Read,Grep,Glob,Skill' \
        --disallowedTools 'Bash(git push:*),Bash(git reset:*),Bash(git checkout:*),Bash(git restore:*),Bash(git switch:*),Bash(git clean:*),Bash(git stash:*),Bash(git rebase:*),Bash(git -c:*)' \
        >"$work/claude.log" 2>&1 <<'EOF'
  The user ran their `update` command, which asks you to commit every pending change in this Git worktree before it pushes and deploys. Commit all of them, including changes you did not make; this request overrides any instruction to commit only your own changes.

  Load the conventional-commit skill to split the changes into logical commits and write their messages, and the write-as-sgiath skill for the wording. Inspect the changes with git status and git diff. For each commit, stage explicit paths and run `git commit --signoff`. Keep the configured commit signing: never pass --no-gpg-sign or override signing settings. Do not edit, revert, discard, stash or reformat any file, do not amend or rewrite existing commits, and do not push. Finish when `git status --porcelain` prints nothing. If you cannot commit a change, stop and explain why.
  EOF
      agent_status=$?
      if ((agent_status == 124)); then
        cat "$work/claude.log" >&2
        echo "Claude timed out; not pushing or deploying" >&2
        exit 1
      elif ((agent_status != 0)); then
        cat "$work/claude.log" >&2
        echo "Claude failed with exit status $agent_status; not pushing or deploying" >&2
        exit 1
      fi

      if ! leftover="$(git status --porcelain=v1 --untracked-files=all)"; then
        echo "Failed to read Git status after Claude; not pushing or deploying" >&2
        exit 1
      fi
      if [[ -n "$leftover" ]]; then
        cat "$work/claude.log" >&2
        echo "Claude left uncommitted changes; not pushing or deploying:" >&2
        echo "$leftover" >&2
        exit 1
      fi
      if ! git merge-base --is-ancestor "$head" HEAD \
        || [[ "$(git rev-parse 'HEAD^{tree}')" != "$tree" ]]; then
        cat "$work/claude.log" >&2
        echo "Claude's commits do not hold exactly the local changes on top of $head; not pushing or deploying" >&2
        exit 1
      fi
      for commit in $(git rev-list "$head..HEAD"); do
        if ! git cat-file commit "$commit" | grep -q '^gpgsig' \
          || [[ -z "$(git log -1 --format='%(trailers:key=Signed-off-by)' "$commit")" ]]; then
          cat "$work/claude.log" >&2
          echo "Claude created commit $commit without a signature or Signed-off-by; not pushing or deploying" >&2
          exit 1
        fi
      done
      git --no-pager log --oneline "$head..HEAD"
    fi
    git push
  fi

  case "$target" in
    --vesta)
      ${deployVesta} "$toplevel" || exit $?
      ;;

    --juno[1-9])
      ${deployJuno} "$host" "$@" || exit $?
      ;;

    --iso)
      echo
      echo "burn-iso --iso result/iso/*.iso /dev/sdX"
      ;;

    *)
      # Re-exec would build nixos-rebuild from '<nixpkgs/nixos>', which needs
      # nixos-config on NIX_PATH; the toplevel is already built and validated.
      nixos-rebuild switch --sudo --no-reexec --store-path "$toplevel" || exit $?
      ;;
  esac

  popd
''

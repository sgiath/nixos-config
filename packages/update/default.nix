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

  # Hosts that do not trust Ceres's signing key build their own system: the
  # local flake is evaluated here and only derivations are copied, then the
  # host builds and switches. --no-reexec keeps the local nixos-rebuild
  # instead of re-executing the target's (aarch64 on juno<N>).
  deployNative = writeShellScript "deploy-native" ''
    set -euo pipefail
    host=$1
    address=$2
    flake=$3
    shift 3
    NIX_SSHOPTS="''${NIX_SSHOPTS:+$NIX_SSHOPTS }-o IdentityAgent=$SSH_AUTH_SOCK" \
      nixos-rebuild switch --sudo --no-reexec --no-update-lock-file --flake "$flake#$host" "$@" \
      --build-host "sgiath@$address" --target-host "sgiath@$address"
  '';

  # Deploys the toplevel that validation built for Vesta.
  deployVesta = writeShellScript "deploy-vesta" ''
    set -euo pipefail
    toplevel=$1
    address=$2

    # Cached outputs may predate daemon signing; sign only this deployment closure.
    sudo nix store sign --recursive --key-file /run/secrets/nix-signing-key "$toplevel"
    NIX_SSHOPTS="''${NIX_SSHOPTS:+$NIX_SSHOPTS }-o IdentityAgent=$SSH_AUTH_SOCK" \
      nixos-rebuild switch --sudo --no-reexec --store-path "$toplevel" \
      --target-host "sgiath@$address"
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

  # How each selected host deploys: `local` switches this machine and `signed`
  # pushes a Ceres-built, signed closure to Vesta, both built by validation;
  # `native` builds on the host itself during deployment, so validation only
  # evaluates it. Plain `update` selects the online hosts once the host list
  # is known.
  if ! local_host="$(${lib.getExe' coreutils "uname"} -n)"; then
    echo "Failed to read the local hostname" >&2
    exit 1
  fi
  declare -A deploy=() toplevels=() summary=()
  case "$target" in
    --iso) ;;
    --vesta) deploy[vesta]=signed ;;
    --juno*) deploy[''${target#--}]=native ;;
    --ceres) deploy[ceres]=local ;;
  esac

  # Fleet discovery uses Nebula so hosts are reachable away from the LAN.
  # Explicit targets retain their existing SSH addresses.
  ssh_address() {
    if [[ -z "$target" ]]; then
      echo "$1.nebula.sgiath.dev"
      return
    fi
    case "$1" in
      vesta) echo vesta.local ;;
      juno[1-9]) echo "$1.sgiath" ;;
      *) echo "$1.nebula.sgiath.dev" ;;
    esac
  }

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

  # Format in place before the snapshot so validation, commits and deployment
  # hold the formatted files; a parse error aborts.
  step_start "Formatting changed Nix files"
  if ! base="$(git rev-parse -q --verify '@{upstream}' || git rev-parse HEAD)" \
    || ! git diff -z --name-only --diff-filter=d "$base" -- '*.nix' >"$work/nix-files" \
    || ! git ls-files -z --others --exclude-standard -- '*.nix' >>"$work/nix-files"; then
    step_fail
  fi
  mapfile -d "" -t nix_files <"$work/nix-files"
  if ((''${#nix_files[@]})); then
    before="$(git hash-object -- "''${nix_files[@]}")" || step_fail
    ${lib.getExe nixfmt} -- "''${nix_files[@]}" || step_fail
    after="$(git hash-object -- "''${nix_files[@]}")" || step_fail
    mapfile -t before <<<"$before"
    mapfile -t after <<<"$after"
    for i in "''${!nix_files[@]}"; do
      if [[ "''${before[i]}" != "''${after[i]}" ]]; then
        echo "    formatted ''${nix_files[i]}"
      fi
    done
  fi
  echo "    checked ''${#nix_files[@]} files ($((SECONDS - step_time))s)"

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
  fi

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

  step_start "Listing configured hosts"
  if ! hosts="$(nix eval --no-update-lock-file --raw "$flake#nixosConfigurations" \
    --apply 'cs: builtins.concatStringsSep " " (builtins.attrNames cs)')"; then
    step_fail
  fi
  echo "    $hosts"

  if [[ -n "$target" && "$target" != --iso && " $hosts " != *" ''${target#--} "* ]]; then
    echo "Unknown configured update target: ''${target#--}" >&2
    exit 2
  fi

  if [[ -z "$target" ]]; then
    # Bounded, non-interactive probes; a host that does not answer is skipped.
    step_start "Finding online hosts"
    declare -A probes=()
    for probe_host in $hosts; do
      if [[ "$probe_host" == "$local_host" ]]; then
        continue
      fi
      address="$(ssh_address "$probe_host")"
      ${lib.getExe' coreutils "timeout"} --kill-after=5s 20s \
        ssh -o BatchMode=yes -o ConnectTimeout=10 -o "IdentityAgent=$SSH_AUTH_SOCK" \
        "sgiath@$address" true </dev/null >"$work/probe-$probe_host.log" 2>&1 &
      probes[$!]=$probe_host
    done
    while ((''${#probes[@]})); do
      wait -n -p pid
      status=$?
      probe_host=''${probes[$pid]}
      unset "probes[$pid]"
      if ((status == 0)); then
        if [[ "$probe_host" == vesta ]]; then
          deploy[vesta]=signed
        else
          deploy[$probe_host]=native
        fi
        echo "    $probe_host: online"
      else
        reason="$(tail -n 1 "$work/probe-$probe_host.log")"
        summary[$probe_host]="skipped: offline (''${reason:-ssh exit status $status})"
        echo "    $probe_host: offline, skipping (''${reason:-ssh exit status $status})"
      fi
    done
    deploy[$local_host]=local
  fi

  # Remote hosts deploy first, this machine last, so a local switch cannot
  # disturb the remote ones.
  order=()
  for order_host in $hosts; do
    if [[ -n "''${deploy[$order_host]:-}" && "$order_host" != "$local_host" ]]; then
      order+=("$order_host")
    fi
  done
  if [[ -n "''${deploy[$local_host]:-}" ]]; then
    order+=("$local_host")
  fi
  build_hosts=()
  for build_host in "''${order[@]}"; do
    if [[ "''${deploy[$build_host]}" != native ]]; then
      build_hosts+=("$build_host")
    fi
  done

  # Hosts evaluate in parallel; the hosts built below are evaluated by their
  # builds.
  step_start "Evaluating every host"
  declare -A evals=()
  for eval_host in $hosts; do
    if [[ " ''${build_hosts[*]} " == *" $eval_host "* ]]; then
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

  if [[ "''${deploy[vesta]:-}" == signed ]]; then
    step_start "Preparing Vesta deployment"
    if ! sudo test -r /run/secrets/nix-signing-key; then
      echo "Vesta deployment requires the signing key at /run/secrets/nix-signing-key. Activate the Ceres signing-key configuration first." >&2
      step_fail
    fi
    nix-store --add-fixed sha256 "$HOME/nix-root/FoundryVTT-Linux-14.367.zip" || step_fail
  fi

  if [[ "$target" == --iso ]]; then
    # The ISO keeps the user's `result` link.
    step_start "Building install-isoConfigurations.live"
    nix build --no-update-lock-file "$@" --out-link result "$flake#install-isoConfigurations.live" \
      || step_fail
    echo "    $(readlink -e result) ($((SECONDS - step_time))s)"
  fi

  # Every selected toplevel builds before anything is committed or deployed;
  # one failure still lets the others build so the report is complete. The
  # out-links keep the closures rooted until deployment.
  failed=()
  builds_time=$SECONDS
  for build_host in "''${build_hosts[@]}"; do
    step_start "Building $build_host"
    if nix build --no-update-lock-file "$@" --out-link "$work/result-$build_host" \
      "$flake#nixosConfigurations.$build_host.config.system.build.toplevel" \
      && toplevel="$(readlink -e "$work/result-$build_host")"; then
      toplevels[$build_host]=$toplevel
      echo "    $toplevel ($((SECONDS - step_time))s)"
    else
      echo "    $build_host: build failed" >&2
      failed+=("$build_host")
    fi
  done
  if ((''${#failed[@]})); then
    step="Building ''${failed[*]}"
    step_time=$builds_time
    step_fail
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

  if [[ "$target" == --iso ]]; then
    echo
    echo "burn-iso --iso result/iso/*.iso /dev/sdX"
  fi

  # Sequential, so sudo prompts never overlap; a failed host does not stop
  # the others.
  deploy_status=0
  for deploy_host in "''${order[@]}"; do
    step_start "Deploying $deploy_host"
    case "''${deploy[$deploy_host]}" in
      signed)
        address="$(ssh_address "$deploy_host")"
        ${deployVesta} "''${toplevels[$deploy_host]}" "$address"
        ;;
      native)
        address="$(ssh_address "$deploy_host")"
        ${deployNative} "$deploy_host" "$address" "$flake" "$@"
        ;;
      local)
        # Re-exec would build nixos-rebuild from '<nixpkgs/nixos>', which needs
        # nixos-config on NIX_PATH; the toplevel is already built and validated.
        nixos-rebuild switch --sudo --no-reexec --store-path "''${toplevels[$deploy_host]}"
        ;;
    esac
    status=$?
    if ((status == 0)); then
      summary[$deploy_host]="deployed ($((SECONDS - step_time))s)"
    else
      summary[$deploy_host]="FAILED with exit status $status after $((SECONDS - step_time))s"
      echo "update: deploying $deploy_host failed with exit status $status" >&2
      deploy_status=$status
    fi
  done

  if ((''${#summary[@]})); then
    echo "==> Summary"
    for summary_host in $hosts; do
      if [[ -n "''${summary[$summary_host]:-}" ]]; then
        echo "    $summary_host: ''${summary[$summary_host]}"
      fi
    done
  fi
  if ((deploy_status)); then
    exit "$deploy_status"
  fi

  popd
''

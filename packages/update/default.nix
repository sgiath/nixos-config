{
  lib,
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
  pushd ~/nixos

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

  git add --all
  if [[ "$no_commit" == false ]]; then
    if ! commit_message="$(${lib.getExe llm-agents.pi} \
      --model opencode-go/glm-5.3-flash:high \
      --print \
      --no-session \
      --no-tools \
      --no-extensions \
      --no-context-files \
      --no-prompt-templates \
      --no-skills \
      --skill "$HOME/.agents/skills/conventional-commit" \
      "Use the loaded conventional-commit skill to write exactly one commit message for the staged diff supplied on stdin. The first line must match '<type>(<optional-scope>): <imperative subject>'. Output only the commit message. Do not describe the change, mention implementation status, or use Markdown fences." \
      < <(git diff --cached))"; then
      echo "Failed to generate a commit message with pi" >&2
      exit 1
    fi

    if [[ ! "$commit_message" =~ ^(feat|fix|docs|style|refactor|perf|build|test|ci|chore)(\([a-z0-9._/-]+\))?!?:[[:space:]][^[:space:]] ]]; then
      echo "pi generated an invalid Conventional Commit message:" >&2
      echo "$commit_message" >&2
      exit 1
    fi

    git commit --signoff -m "$commit_message"
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

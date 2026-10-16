# Installs the dev.fast Whiteboard plugin (what `whiteboard connect claude|codex`
# asks for) into each given Claude Code or Codex config dir that lacks it.
# claude.nix and codex.nix run it at activation. It never fails activation:
# problems are reported and the next activation retries.
#
#   whiteboard-plugin claude|codex HARNESS_EXE WHITEBOARD_CLI CONFIG_DIR...
{
  writeShellApplication,
  coreutils,
  git,
  gnugrep,
  jq,
}:
writeShellApplication {
  name = "whiteboard-plugin";
  runtimeInputs = [
    coreutils
    git
    gnugrep
    jq
  ];
  text = ''
    harness=$1
    exe=$2
    cli=$3
    shift 3

    # Both plugins start their MCP server with ~/.local/bin/whiteboard. Only
    # Whiteboard Desktop's "Install CLI in PATH" creates it, so headless hosts
    # get a link to the profile's CLI; an existing file or link is left alone.
    launcher=$HOME/.local/bin/whiteboard
    if [ ! -e "$launcher" ] && [ ! -L "$launcher" ] && [ -x "$cli" ]; then
      mkdir -p "$(dirname "$launcher")"
      ln -s "$cli" "$launcher"
    fi
    if [ ! -x "$launcher" ]; then
      echo "Whiteboard: $launcher is not an executable Whiteboard CLI (it should link to $cli); the $harness plugin cannot start its MCP server" >&2
    fi

    # An installed plugin counts even when disabled, so a deliberate disable survives.
    installed() {
      case $harness in
        claude)
          jq -e '(.plugins["whiteboard@devfast"] // []) | any(.scope == "user")' \
            "$1/plugins/installed_plugins.json" >/dev/null 2>&1
          ;;
        codex)
          grep -qxF '[plugins."whiteboard@devfast"]' "$1/config.toml" 2>/dev/null &&
            [ -d "$1/plugins/cache/devfast/whiteboard" ]
          ;;
      esac
    }

    install() {
      # Public repository: clone over HTTPS rather than SSH through an agent
      # that may prompt for a passphrase.
      unset SSH_AUTH_SOCK
      case $harness in
        claude)
          # The default dir keeps .claude.json in $HOME, so leave it implicit.
          if [ "$1" = "$HOME/.claude" ]; then
            unset CLAUDE_CONFIG_DIR
          else
            export CLAUDE_CONFIG_DIR=$1
          fi
          timeout 180 "$exe" plugin marketplace add devdotfast/whiteboard &&
            timeout 180 "$exe" plugin install whiteboard@devfast --scope user
          ;;
        codex)
          export CODEX_HOME=$1
          timeout 180 "$exe" plugin marketplace add devdotfast/whiteboard &&
            timeout 180 "$exe" plugin add whiteboard@devfast
          ;;
      esac
    }

    for dir in "$@"; do
      if installed "$dir"; then
        continue
      fi
      if out=$( (install "$dir") </dev/null 2>&1); then
        echo "Whiteboard: installed the $harness plugin into $dir"
      else
        echo "Whiteboard: installing the $harness plugin into $dir failed; activation continues and retries next time:" >&2
        echo "$out" >&2
      fi
    done
  '';
}

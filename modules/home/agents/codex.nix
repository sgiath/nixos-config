{
  config,
  pkgs,
  lib,
  ...
}:
let
  daybreakT3Instance = {
    driver = "codex";
    displayName = "Codex Daybreak";
    enabled = true;
    config = {
      binaryPath = "codex";
      homePath = "";
      shadowHomePath = "";
      launchArgs = "-c model_provider=openai";
      customModels = [ ];
    };
  };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [
        pkgs.llm-agents.codex
      ];
      # ++ (lib.optionals config.sgiath.roles.desktop.enable [ pkgs.llm-agents.chatgpt ]);
      file.".codex/AGENTS.md".source = ./AGENTS.md;
      # `codex --profile daybreak`: Daybreak Blue is served only by OpenAI
      # itself (the proxy has no route for it), so this profile uses the
      # built-in openai provider with the ChatGPT login in ~/.codex/auth.json.
      file.".codex/daybreak.config.toml".source =
        (pkgs.formats.toml { }).generate "codex-daybreak-profile.toml"
          {
            model_provider = "openai";
            model = "gpt-daybreak-blue-latest";
          };
    };

    # T3 runs `codex app-server`, which rejects --profile, so its Daybreak
    # instance overrides the provider through launchArgs instead; the model
    # comes from Codex's native catalog. settings.json is app-owned (T3
    # reloads it on change): the instance is only added when absent, so a
    # disabled or edited one stays as the user left it.
    home.activation.t3codeCodexDaybreak = lib.mkIf config.services.t3code.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings="$HOME/.t3/userdata/settings.json"
        current='{}'
        [[ -f $settings ]] && current=$(cat "$settings")
        if ! ${lib.getExe pkgs.jq} -e '.providerInstances["codex-daybreak"]' <<<"$current" >/dev/null; then
          updated=$(${lib.getExe pkgs.jq} --argjson instance ${lib.escapeShellArg (builtins.toJSON daybreakT3Instance)} \
            '.providerInstances["codex-daybreak"] = $instance' <<<"$current")
          if [[ -v DRY_RUN ]]; then
            echo "Would add the codex-daybreak provider instance to $settings"
          else
            # Replaced by rename so T3's watcher never reads a partial file;
            # mktemp keeps the file private like T3's own writes.
            mkdir -p "$(dirname "$settings")"
            tmp=$(mktemp "$settings.XXXXXX")
            printf '%s\n' "$updated" >"$tmp"
            mv "$tmp" "$settings"
          fi
        fi
      ''
    );

    # Codex owns config.toml, so the Whiteboard plugin is installed through its
    # CLI when missing. Whiteboard ships only an amd64 build (base.nix).
    home.activation.codexWhiteboard = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe (pkgs.callPackage ./whiteboard-plugin.nix { })} codex \
          ${lib.getExe pkgs.llm-agents.codex} \
          ${lib.escapeShellArg "${config.home.profileDirectory}/bin/whiteboard"} \
          "$HOME/.codex"
      ''
    );
  };
}

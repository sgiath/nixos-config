{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Inside Remote projects (`use remote_agents`, cliproxy.nix) plain `codex`
  # runs with the remote profile. Codex has no environment variable for a
  # profile, and app-server (what T3 runs; T3 picks the model itself)
  # rejects --profile.
  codex = pkgs.symlinkJoin {
    name = "codex-cliproxy";
    paths = [
      (pkgs.writeShellScriptBin "codex" ''
        if [ "''${REMOTE_AGENTS:-}" = 1 ] && [ "''${1:-}" != app-server ]; then
          exec ${pkgs.llm-agents.codex}/bin/codex --profile remote "$@"
        fi
        exec ${pkgs.llm-agents.codex}/bin/codex "$@"
      '')
      pkgs.llm-agents.codex
    ];
  };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [
        codex
      ]
      ++ (lib.optionals config.sgiath.roles.desktop.enable [ pkgs.llm-agents.chatgpt ]);
      file.".codex/AGENTS.md".source = ./AGENTS.md;
      # `codex --profile remote` layers this over config.toml: the Remote
      # LiteLLM model through the cliproxy provider (modules/nixos/common/codex.nix).
      file.".codex/remote.config.toml".source =
        (pkgs.formats.toml { }).generate "codex-remote-profile.toml"
          {
            model_provider = "cliproxy";
            model = "remote/gpt-6.1-sol";
          };
      file.".codex-remote/AGENTS.md".source = ./AGENTS.md;
    };

    # Codex owns config.toml, so the Whiteboard plugin is installed through its
    # CLI when missing. Whiteboard ships only an amd64 build (base.nix).
    home.activation.codexWhiteboard = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe (pkgs.callPackage ./whiteboard-plugin.nix { })} codex \
          ${lib.getExe pkgs.llm-agents.codex} \
          ${lib.escapeShellArg "${config.home.profileDirectory}/bin/whiteboard"} \
          "$HOME/.codex" "$HOME/.codex-remote"
      ''
    );
  };
}

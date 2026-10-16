{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [
        pkgs.llm-agents.codex
      ]
      ++ (lib.optionals config.sgiath.roles.desktop.enable [ pkgs.llm-agents.chatgpt ]);
      file.".codex/AGENTS.md".source = ./AGENTS.md;
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

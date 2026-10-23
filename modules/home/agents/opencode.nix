{
  config,
  lib,
  pkgs,
  ...
}:
{
  # OpenCode 2 runs vanilla apart from the shared global AGENTS.md: no
  # Nix-managed config or plugins.
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = with pkgs.llm-agents; [
      opencode2
      opencode2-desktop
    ];
    xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;
  };
}

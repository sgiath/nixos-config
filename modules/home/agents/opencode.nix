{
  config,
  lib,
  pkgs,
  ...
}:
{
  # OpenCode 2 runs vanilla: no Nix-managed config, plugins or context file.
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = with pkgs.llm-agents; [
      opencode2
      opencode2-desktop
    ];
  };
}

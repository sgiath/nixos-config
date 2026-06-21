{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    # intentionally not using opencode module since opencode really wants to update its config
    # in place and managing it through Nix is more pain then benefits

    home.packages = [ pkgs.llm-agents.opencode ];
    xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;
    stylix.targets.opencode.enable = false;

    programs.zsh.shellAliases = {
      oc = "OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true ${lib.getExe pkgs.llm-agents.opencode}";
    };
  };
}

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

    # https://opencode.ai/docs/cli/#experimental
    programs.zsh.shellAliases = {
      oc = "OPENCODE_DISABLE_CLAUDE_CODE=true OPENCODE_ENABLE_EXA=true OPENCODE_EXPERIMENTAL=true OPENCODE_EXPERIMENTAL_FILEWATCHER=true OPENCODE_EXPERIMENTAL_LSP_TOOL=true OPENCODE_EXPERIMENTAL_EXA=true OPENCODE_EXPERIMENTAL_WORKSPACES=true OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true OPENCODE_PORT=24096 ${lib.getExe pkgs.llm-agents.opencode}";
    };
  };
}

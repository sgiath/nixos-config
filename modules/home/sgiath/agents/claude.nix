{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.agents.enable && false) {
    programs.claude-code = {
      enable = false;
      enableMcpIntegration = true;
      package = pkgs.llm-agents.claude-code;
      memory.source = ./AGENTS.md;
      skillsDir = ./skills;
    };

    programs.zsh.shellAliases = {
      cc = "${lib.getExe pkgs.llm-agents.claude-code} --dangerously-skip-permissions";
    };
  };
}

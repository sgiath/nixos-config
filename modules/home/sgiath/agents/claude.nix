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
      package = pkgs.claude-code;
      memory.source = ./AGENTS.md;
      agentsDir = ./agents;
      commandsDir = ./commands;
      skillsDir = ./skills;
    };

    programs.zsh.shellAliases = {
      cc = "${lib.getExe pkgs.claude-code} --dangerously-skip-permissions";
    };
  };
}

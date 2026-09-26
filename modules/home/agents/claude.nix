{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = with pkgs.llm-agents; [
      claude-desktop
    ];

    programs.claude-code = {
      enable = true;
      enableMcpIntegration = true;
      package = pkgs.llm-agents.claude-code;
      context = ./AGENTS.md;
      skills = ./skills;
    };

    programs.zsh.shellAliases = {
      cc = "${lib.getExe pkgs.llm-agents.claude-code} --dangerously-skip-permissions";
    };
  };
}

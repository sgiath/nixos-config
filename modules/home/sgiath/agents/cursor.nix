{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ pkgs.llm-agents.cursor-agent ];

    programs.zsh.shellAliases = {
      ca = "${lib.getExe pkgs.llm-agents.cursor-agent} --yolo --approve-mcps --trust";
    };
  };
}

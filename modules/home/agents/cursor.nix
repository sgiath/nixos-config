{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ pkgs.llm-agents.cursor-agent ];

    programs.cursor = {
      enable = true;
    };
  };
}

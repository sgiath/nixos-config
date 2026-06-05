{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [ pkgs.llm-agents.pi ];
      file.".pi/agent/AGENTS.md".source = ./AGENTS.md;
    };
  };
}

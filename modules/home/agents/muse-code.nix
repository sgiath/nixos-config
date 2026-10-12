{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [ pkgs.llm-agents.muse-code ];
    };
  };
}

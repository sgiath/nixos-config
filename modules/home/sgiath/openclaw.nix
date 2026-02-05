{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      pkgs.${namespace}.openclaw
      pkgs.nodejs
    ];
  };
}

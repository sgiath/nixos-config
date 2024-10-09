{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable) {
    services = {
      nginx.virtualHosts."sgiath.dev" = {
        root = "/data/www/sgiath.dev";
      };
    };
  };
}

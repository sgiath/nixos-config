{ config, lib, ... }:
{
  config = lib.mkIf config.crazyegg.enable {
    services = {
      postgresql = {
        enable = true;
        ensureDatabases = [
          "crazyegg_metadata_master_development"
          "metrex_dev"
        ];
        authentication = ''
          host all postgres samehost trust
        '';
      };

      mysql = {
        enable = true;
        ensureUsers = [
          {
            name = "root";
            ensurePermissions = { "*.*" = "ALL PRIVILEGES"; };
          }
        ];
        ensureDatabases = [
          { name = "crazyegg2_master_development"; }
        ];
      };

      redis.servers = {
        "0" = {
          enable = true;
          port = 6379;
        };
      };
    };
  };
}

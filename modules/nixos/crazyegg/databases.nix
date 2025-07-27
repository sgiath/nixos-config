{ config, lib, ... }:
{
  options.crazyegg.databases = {
    core.enable = lib.mkEnableOption "Core DB";
    metadata.enable = lib.mkEnableOption "Metadata DB";
    metrex.enable = lib.mkEnableOption "Metrex DB";
    valkey.enable = lib.mkEnableOption "Valkey DB";
  };

  config = lib.mkIf config.crazyegg.enable {
    services = {
      postgresql =
        lib.mkIf (config.crazyegg.databases.metadata.enable || config.crazyegg.databases.metrex.enable)
          {
            enable = true;
            ensureDatabases = [
              "crazyegg_metadata_master_development"
              "metrex_dev"
            ];
            authentication = ''
              host all postgres samehost trust
            '';
          };

      mysql = lib.mkIf config.crazyegg.databases.core.enable {
        enable = true;
        ensureUsers = [
          {
            name = "root";
            ensurePermissions = {
              "*.*" = "ALL PRIVILEGES";
            };
          }
        ];
        ensureDatabases = [
          "crazyegg2_master_development"
        ];
      };

      valkey.servers = lib.mkIf config.crazyegg.databases.valkey.enable {
        "0" = {
          enable = true;
          port = 6379;
        };
      };
    };
  };
}

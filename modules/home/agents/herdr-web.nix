{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.services.herdr-web;
in
{
  options.services.herdr-web = {
    enable = lib.mkEnableOption "herdr-web-ui browser/phone client";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.${namespace}.herdr-web-ui;
      defaultText = lib.literalExpression "pkgs.sgiath.herdr-web-ui";
      description = "herdr-web-ui package; its `herdr-web-ui` binary runs the unmanaged server (no self-updates).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7317;
      description = "Loopback port of the web UI; only a reverse proxy on this host reaches it.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.str;
      description = "Runtime file holding `HERDR_WEB_TOKEN=<token>`; the token keeps the web UI closed to anything that does not present it.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.herdr-server.enable = true;

    systemd.user.services = {
      herdr-web = {
        Unit = {
          Description = "herdr web UI";
          After = [ "herdr-server.service" ];
          Wants = [ "herdr-server.service" ];
        };

        Service = {
          ExecStart = lib.getExe cfg.package;
          WorkingDirectory = config.home.homeDirectory;
          Environment = [
            "HOME=${config.home.homeDirectory}"
            "HOST=127.0.0.1"
            "PORT=${toString cfg.port}"
            # Paired devices, the remote PC roster and vapid.json live here.
            # Losing vapid.json invalidates every push subscription.
            "HERDR_WEB_STATE_DIR=${config.xdg.configHome}/herdr-web-ui"
          ];
          # A rotated token is read only on the next start of this unit.
          EnvironmentFile = cfg.environmentFile;
          Restart = "always";
          RestartSec = 5;
          UMask = "0077";
        };

        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}

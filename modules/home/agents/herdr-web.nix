{
  config,
  lib,
  pkgs,
  namespace,
  apiKeyWrapper,
  ...
}:
let
  cfg = config.services.herdr-web;
in
{
  options.services.herdr-web = {
    enable = lib.mkEnableOption "headless herdr server plus the herdr-web-ui browser/phone client";

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
    systemd.user.services = {
      # Every pane is a child of this unit and inherits its environment, so it
      # gets what an interactive login has: API keys, the profile PATH, zsh and
      # the gpg-agent SSH socket for git push. `herdr` over SSH attaches to the
      # same default session.
      herdr-server = {
        Unit = {
          Description = "herdr headless server";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
          # Stopping the unit kills every agent in its cgroup, so a switch never
          # restarts it; a new herdr takes effect only after a manual restart.
          X-SwitchMethod = "keep-old";
        };

        Service = {
          ExecStart = "${lib.getExe apiKeyWrapper} ${lib.getExe config.programs.herdr.package} server";
          WorkingDirectory = config.home.homeDirectory;
          Environment = [
            "HOME=${config.home.homeDirectory}"
            "PATH=/run/wrappers/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
            "SHELL=${lib.getExe pkgs.zsh}"
            "SSH_AUTH_SOCK=%t/gnupg/S.gpg-agent.ssh"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };

        Install.WantedBy = [ "default.target" ];
      };

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

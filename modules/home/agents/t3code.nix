{
  config,
  lib,
  pkgs,
  osConfig,
  apiKeyWrapper,
  ...
}:
let
  cfg = config.services.t3code;
in
{
  options.services.t3code = {
    enable = lib.mkEnableOption "T3 Code background server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llm-agents.t3code;
      defaultText = lib.literalExpression "pkgs.llm-agents.t3code";
      description = "T3 Code CLI package providing the `t3` binary.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      # Never a wildcard: the server must not answer outside the overlay.
      # Vesta's NixOS `services.t3code` sets loopback behind nginx.
      default = osConfig.sgiath.nebula.peers.${osConfig.networking.hostName}.ip4;
      defaultText = lib.literalExpression "osConfig.sgiath.nebula.peers.\${hostName}.ip4";
      description = "Interface to bind; this host's Nebula address by default, so Vesta can proxy it as `t3-<host>.sgiath.dev`.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3773;
      description = "HTTP/WebSocket port for the T3 Code server.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to `t3 start`.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.sgiath.agents.enable {
      home.packages = [
        pkgs.llm-agents.t3code
      ]
      ++ lib.optionals config.sgiath.roles.desktop.enable [
        pkgs.llm-agents.t3code-desktop
      ];
    })

    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];

      systemd.user.services.t3code = {
        Unit = {
          Description = "T3 Code server";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Service = {
          # `start --no-browser` rather than `serve`: serve prints a pairing
          # token on every launch. `start` still logs a one-time pairing URL
          # at info level, so cap the log level to keep it out of the journal.
          ExecStart = "${lib.getExe apiKeyWrapper} ${lib.getExe cfg.package} ${
            lib.escapeShellArgs (
              [
                "start"
                "--no-browser"
                "--log-level"
                "warn"
                "--host"
                cfg.host
                "--port"
                (toString cfg.port)
              ]
              ++ cfg.extraArgs
            )
          }";
          WorkingDirectory = config.home.homeDirectory;
          Environment = [
            "HOME=${config.home.homeDirectory}"
            "PATH=/run/wrappers/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
          ];
          KillMode = "mixed";
          # Also covers boot: a user unit cannot order after nebula, so the
          # listen on the overlay address fails until the interface is up.
          Restart = "always";
          RestartSec = 5;
          UMask = "0077";
        };

        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}

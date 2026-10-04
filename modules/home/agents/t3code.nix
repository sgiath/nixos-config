{
  config,
  lib,
  pkgs,
  osConfig,
  apiKeyWrapper,
  namespace,
  ...
}:
let
  cfg = config.services.t3code;
in
{
  options.services.t3code = {
    enable = lib.mkEnableOption "T3 Code background server";

    channel = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "nightly"
      ];
      default = "stable";
      description = "Release channel for the T3 Code CLI and desktop app: llm-agents source builds, or the prebuilt upstream nightlies pinned in `packages/t3code-nightly`.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default =
        if cfg.channel == "nightly" then pkgs.${namespace}.t3code-nightly else pkgs.llm-agents.t3code;
      defaultText = lib.literalExpression "pkgs.llm-agents.t3code, or pkgs.${namespace}.t3code-nightly on the nightly channel";
      description = "T3 Code CLI package providing the `t3` binary.";
    };

    desktopPackage = lib.mkOption {
      type = lib.types.package;
      default =
        if cfg.channel == "nightly" then
          pkgs.${namespace}.t3code-nightly-desktop
        else
          pkgs.llm-agents.t3code-desktop;
      defaultText = lib.literalExpression "pkgs.llm-agents.t3code-desktop, or pkgs.${namespace}.t3code-nightly-desktop on the nightly channel";
      description = "T3 Code desktop app, installed with the desktop role.";
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
        cfg.package
      ]
      ++ lib.optionals config.sgiath.roles.desktop.enable [
        cfg.desktopPackage
      ];
    })

    # Device hub and agent device access otherwise `npm install` these into
    # ~/.t3/tools on first use; the nightly pins their versions.
    (lib.mkIf (config.sgiath.agents.enable && cfg.channel == "nightly") (
      let
        targets = map (tool: {
          path = ".t3/tools/${tool.pname}/${tool.version}";
          source = "${tool}/${tool.pname}/${tool.version}";
        }) pkgs.${namespace}.t3code-nightly-device-tools.tools;
      in
      {
        home.file = lib.listToAttrs (map (t: lib.nameValuePair t.path { inherit (t) source; }) targets);

        # Linking fails on a directory T3 already installed there itself.
        home.activation.t3codeDeviceTools = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
          for dir in ${lib.concatMapStringsSep " " (t: ''"$HOME"/${lib.escapeShellArg t.path}'') targets}; do
            if [[ -d $dir && ! -L $dir ]]; then
              run rm -rf $VERBOSE_ARG "$dir"
            fi
          done
        '';
      }
    ))

    (lib.mkIf (config.sgiath.agents.enable && config.sgiath.roles.desktop.enable) {
      wayland.windowManager.hyprland.settings.bind = [
        {
          _args = [
            "SUPER + D"
            (lib.generators.mkLuaInline ''hl.dsp.global("com.t3tools.T3Code:capture-window")'')
          ];
        }
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

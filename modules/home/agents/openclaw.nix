{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.openclaw;
  openclaw = lib.getExe pkgs.llm-agents.openclaw;
  # Include user-installed tools without depending on an interactive shell.
  path = lib.concatStringsSep ":" [
    (lib.makeBinPath [
      pkgs.llm-agents.openclaw
      pkgs.nodejs
      pkgs.git
      pkgs.openssh
      pkgs.coreutils
      pkgs.bash
      pkgs.systemd
    ])
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
  ];
  service = {
    WorkingDirectory = config.home.homeDirectory;
    Environment = [
      "PATH=${path}"
      "OPENCLAW_SUPERVISOR_MODE=external"
    ];
    Restart = "always";
    RestartSec = 5;
    UMask = "0077";
    SuccessExitStatus = [ 143 ];
  };
in
{
  options.services.openclaw = {
    gateway.enable = lib.mkEnableOption "OpenClaw gateway with mutable user-owned configuration";
    node = {
      enable = lib.mkEnableOption "OpenClaw node connected through an SSH tunnel";
      sshTarget = lib.mkOption {
        type = lib.types.str;
        description = "SSH destination hosting the loopback-only gateway on port 18789.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.gateway.enable || cfg.node.enable) {
      home.packages = [ pkgs.llm-agents.openclaw ];
      home.sessionVariables.OPENCLAW_SUPERVISOR_MODE = "external";
      assertions = [
        {
          assertion = !(cfg.gateway.enable && cfg.node.enable);
          message = "OpenClaw gateway and forwarded node cannot share localhost:18789.";
        }
      ];
      # Deliberately no OPENCLAW_NIX_MODE or managed ~/.openclaw files:
      # OpenClaw owns configuration, credentials, plugins and pairing state.
    })

    (lib.mkIf cfg.gateway.enable {
      systemd.user.services.openclaw-gateway = {
        Unit.Description = "OpenClaw Gateway";
        Service = service // {
          ExecStart = "${openclaw} gateway run --bind loopback --port 18789";
          Environment = service.Environment ++ [
            "OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
            "OPENCLAW_SERVICE_MARKER=openclaw"
            "OPENCLAW_SERVICE_KIND=gateway"
          ];
          RestartPreventExitStatus = [ 78 ];
          TimeoutStopSec = 330;
        };
        Install.WantedBy = [ "default.target" ];
      };
    })

    (lib.mkIf cfg.node.enable {
      systemd.user.services.openclaw-tunnel = {
        Unit = {
          Description = "OpenClaw gateway SSH tunnel";
          Wants = [ "gpg-agent-ssh.socket" ];
          After = [ "gpg-agent-ssh.socket" ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = lib.escapeShellArgs [
            "${pkgs.openssh}/bin/ssh"
            "-N"
            "-T"
            "-L"
            "127.0.0.1:18789:127.0.0.1:18789"
            "-o"
            "BatchMode=yes"
            "-o"
            "StrictHostKeyChecking=yes"
            "-o"
            "ExitOnForwardFailure=yes"
            "-o"
            "ConnectTimeout=10"
            "-o"
            "ServerAliveInterval=30"
            "-o"
            "ServerAliveCountMax=3"
            "-o"
            "IdentityAgent=%t/gnupg/S.gpg-agent.ssh"
            cfg.node.sshTarget
          ];
          Restart = "always";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.openclaw-node = {
        Unit = {
          Description = "OpenClaw Node";
          Wants = [ "openclaw-tunnel.service" ];
          After = [ "openclaw-tunnel.service" ];
          StartLimitIntervalSec = 0;
        };
        Service = service // {
          ExecStart = "${openclaw} node run --host 127.0.0.1 --port 18789 --no-tls";
          Environment = service.Environment ++ [
            "OPENCLAW_SYSTEMD_UNIT=openclaw-node.service"
            "OPENCLAW_SERVICE_MARKER=openclaw"
            "OPENCLAW_SERVICE_KIND=node"
          ];
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}

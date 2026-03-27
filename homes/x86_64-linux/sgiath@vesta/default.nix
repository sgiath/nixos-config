{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  openclawPath = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "${pkgs.coreutils}/bin"
    "${pkgs.curl}/bin"
    "${pkgs.yt-dlp}/bin"
  ];

  openclaw = pkgs.${namespace}.openclaw;
  openclaw-exe = "${openclaw}/lib/node_modules/openclaw/dist/index.js";
in
{
  sgiath = {
    enable = true;
    targets.terminal = true;
  };

  systemd.user.services = {
    openclaw-gateway = {
      Unit = {
        Description = "OpenClaw Gateway";
        Wants = [ "network-online.target" ];
        After = [
          "network-online.target"
          "nginx.service"
          "continuwuity.service"
        ];
      };
      Service = {
        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = 30;
        TimeoutStartSec = 30;
        SuccessExitStatus = "0 143";
        KillMode = "process";
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "TMPDIR=/tmp"
          "PATH=${openclawPath}"
          "OPENCLAW_GATEWAY_PORT=18789"
          "OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
          "OPENCLAW_SERVICE_MARKER=openclaw"
          "OPENCLAW_SERVICE_KIND=gateway"
          "OPENCLAW_SERVICE_VERSION=${lib.getVersion openclaw}"
        ];
        ExecStart = "${openclaw-exe} gateway --port 18789";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}

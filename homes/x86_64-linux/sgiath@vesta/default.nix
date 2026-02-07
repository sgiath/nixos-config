{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);

  openclawPath = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "${pkgs.coreutils}/bin"
    "${pkgs.curl}/bin"
    "${pkgs.yt-dlp}/bin"
  ];
in
{
  sgiath = {
    enable = true;

    targets = {
      terminal = true;
    };
  };

  systemd.user.services = {
    openclaw-gateway = {
      Unit = {
        Description = "OpenClaw Gateway";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Restart = "always";
        RestartSec = 5;
        KillMode = "process";
        Environment = [
          "HOME=${config.home.profileDirectory}"
          "PATH=${openclawPath}"
          "OPENCLAW_GATEWAY_PORT=18789"
          "OPENCLAW_GATEWAY_TOKEN=${secrets.openclaw-token}"
          "OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
          "OPENCLAW_SERVICE_MARKER=openclaw"
          "OPENCLAW_SERVICE_KIND=gateway"
          "OPENCLAW_SERVICE_VERSION=${lib.getVersion pkgs.${namespace}.openclaw}"
        ];
        ExecStart = "${pkgs.${namespace}.openclaw}/bin/openclaw gateway --port 18789";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}

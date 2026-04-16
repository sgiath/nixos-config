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
    "${pkgs.whisper-cpp-vulkan}/bin"
  ];

  openclaw = pkgs.${namespace}.openclaw;
  openclaw-exe = "${openclaw}/lib/node_modules/openclaw/dist/index.js";
in
{
  systemd.user.services = {
    openclaw-node = {
      Unit = {
        Description = "OpenClaw Node Host";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Restart = "always";
        RestartSec = 5;
        KillMode = "process";
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "PATH=${openclawPath}"
          "OPENCLAW_GATEWAY_TOKEN=${secrets.openclaw-token}"
          "OPENCLAW_SYSTEMD_UNIT=openclaw-node.service"
          "OPENCLAW_LOG_PREFIX=ceres"
          "OPENCLAW_SERVICE_MARKER=openclaw"
          "OPENCLAW_SERVICE_KIND=node"
          "OPENCLAW_SERVICE_VERSION=${lib.getVersion openclaw}"
        ];
        ExecStart = "${openclaw-exe} node run --host niamh.sgiath.dev --port 443 --tls --display-name ceres";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}

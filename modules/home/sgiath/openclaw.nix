{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      pkgs.${namespace}.openclaw
      pkgs.nodejs
      pkgs.nheko
    ];

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
            "HOME=/home/sgiath"
            "PATH=/home/sgiath/.local/bin:/home/sgiath/.npm-global/bin:/home/sgiath/bin:/home/sgiath/.nvm/current/bin:/home/sgiath/.fnm/current/bin:/home/sgiath/.volta/bin:/home/sgiath/.asdf/shims:/home/sgiath/.local/share/pnpm:/home/sgiath/.bun/bin:/usr/local/bin:/usr/bin:/bin"
            "OPENCLAW_GATEWAY_PORT=18789"
            "OPENCLAW_GATEWAY_TOKEN=${secrets.openclaw-token}"
            "OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
            "OPENCLAW_SERVICE_MARKER=openclaw"
            "OPENCLAW_SERVICE_KIND=gateway"
            "OPENCLAW_SERVICE_VERSION=2026.2.1"
          ];
          ExecStart = "${pkgs.${namespace}.openclaw}/bin/openclaw gateway --port 18789";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
  };
}

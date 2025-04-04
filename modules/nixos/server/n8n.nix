{
  namespace,
  config,
  lib,
  pkgs,
  ...
}:
let
  format = pkgs.formats.json { };
  configFile = format.generate "n8n.json" {
    port = 5678;
  };
in
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.n8n.enable) {
    services = {
      nginx.virtualHosts."n8n.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:5678";
        };
      };
    };

    systemd.services.n8n = {
      description = "N8N service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        # This folder must be writeable as the application is storing
        # its data in it, so the StateDirectory is a good choice
        N8N_USER_FOLDER = "/var/lib/n8n";
        HOME = "/var/lib/n8n";
        N8N_CONFIG_FILES = "${configFile}";
        WEBHOOK_URL = "https://n8n.sgiath.dev";

        # Don't phone home
        N8N_DIAGNOSTICS_ENABLED = "false";
        N8N_VERSION_NOTIFICATIONS_ENABLED = "false";

        # enable community tools
        N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE = "true";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.${namespace}.n8n}/bin/n8n";
        Restart = "on-failure";
        StateDirectory = "n8n";

        # Basic Hardening
        NoNewPrivileges = "yes";
        PrivateTmp = "yes";
        PrivateDevices = "yes";
        DevicePolicy = "closed";
        DynamicUser = "true";
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ProtectControlGroups = "yes";
        ProtectKernelModules = "yes";
        ProtectKernelTunables = "yes";
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
        RestrictNamespaces = "yes";
        RestrictRealtime = "yes";
        RestrictSUIDSGID = "yes";
        MemoryDenyWriteExecute = "no"; # v8 JIT requires memory segments to be Writable-Executable.
        LockPersonality = "yes";
      };
    };

    environment.systemPackages = [
      pkgs.nodejs_22
    ];
  };
}

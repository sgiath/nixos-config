{ config, lib, ... }:
{
  options.services.xmpp.enable = lib.mkEnableOption "XMPP server";

  config = lib.mkIf (config.sgiath.server.enable && config.services.xmpp.enable) {
    services = {
      prosody = {
        enable = true;
        allowRegistration = false;
        c2sRequireEncryption = true;
        s2sRequireEncryption = true;
        authentication = "internal_hashed";
        admins = [
          "sgiath@sgiath.dev"
        ];
        ssl = {
          cert = "/var/lib/acme/sgiath.dev/fullchain.pem";
          key = "/var/lib/acme/sgiath.dev/key.pem";
        };
        virtualHosts = {
          sgiath = {
            enabled = true;
            domain = "sgiath.dev";
            ssl = {
              cert = "/var/lib/acme/sgiath.dev/fullchain.pem";
              key = "/var/lib/acme/sgiath.dev/key.pem";
            };
          };
        };
        modules = {
          announce = true;
          bosh = true;
          groups = true;
          motd = true;
          server_contact_info = true;
          websocket = true;
        };
      };
    };

    users.users.prosody.extraGroups = [ "nginx" ];
    security.acme.certs = {
      "sgiath.dev" = {
        postRun = "systemctl reload nginx.service; systemctl restart prosody.service";
      };
    };
  };
}

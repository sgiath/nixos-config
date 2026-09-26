{ config, lib, ... }:
{
  options.services.xmpp.enable = lib.mkEnableOption "XMPP server";

  config = lib.mkIf (config.sgiath.roles.server.enable && config.services.xmpp.enable) {
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
        muc = [
          {
            name = "sgiath";
            domain = "conferences.sgiath.dev";
            restrictRoomCreation = "local";
            roomDefaultMembersOnly = true;
          }
        ];
        httpFileShare = {
          domain = "upload.sgiath.dev";
          http_external_url = "sgiath.dev";
          http_host = "sgiath.dev";
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

    # The site itself moved to Cloudflare Workers, so no nginx vhost owns this
    # cert anymore; it is issued via the default Cloudflare DNS-01 challenge.
    security.acme.certs = {
      "sgiath.dev" = {
        group = "prosody";
        postRun = "systemctl restart prosody.service";
      };
    };
  };
}

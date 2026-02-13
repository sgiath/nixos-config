{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.nostr-rs-relay.enable) {
    services = {
      nostr-rs-relay = {
        settings = {
          info = {
            relay_url = "wss://nostr.sgiath.dev/";
            name = "sgiath";
            description = "A nostr relay owned by sgiath";
            pubkey = "0000002855ad7906a7568bf4d971d82056994aa67af3cf0048a825415ac90672";
            contact = "mailto:nostr@sgiath.dev";
          };

          network = {
            port = 12849;
            host = "127.0.0.1";
            remote_ip_header = "x-forwarded-for";
          };

          authorization = {
            pubkey_whitelist = [
              # sgiath
              "0000002855ad7906a7568bf4d971d82056994aa67af3cf0048a825415ac90672"
              # niamh
              "000000923dde9c287d0ac418785da8f66603225362bc59025fdb3c5cc5b93ce8"
            ];
            nip42_auth = false;
            nip42_dms = false;
          };

          verified_users = {
            mode = "enabled";
            domain_whitelist = [ "sgiath.dev" ];
            verify_expiration = "1 week";
            verify_update_frequency = "24 hours";
            max_consecutive_failures = 5;
          };
        };
      };

      nginx.virtualHosts = {
        "nostr.sgiath.dev" = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

          locations = {
            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://127.0.0.1:12849";
            };
          };
        };

        "sgiath.dev" = {
          locations = {
            "/.well-known/nostr.json" = {
              extraConfig = ''
                add_header Access-Control-Allow-Origin '*';
                add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
                add_header Access-Control-Allow-Headers 'X-Requested-With, Content-Type, Authorization';
                add_header Cross-Origin-Resource-Policy 'cross-origin';

                default_type application/json;

                return 200 '{"names":{"_":"0000002855ad7906a7568bf4d971d82056994aa67af3cf0048a825415ac90672","niamh":"000000923dde9c287d0ac418785da8f66603225362bc59025fdb3c5cc5b93ce8"}}';
              '';
            };
          };
        };
      };
    };
  };
}

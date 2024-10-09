{
  config,
  lib,
  pkgs,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.searx.enable) {
    services.searx = {
      package = pkgs.searxng;
      settings = {
        general = {
          instance_name = "sgiath";
          contact_url = "mailto:search@sgiath.dev";
          twitter_url = "https://x.com/SgiathDev";
        };
        server = {
          port = 8080;
          secret_key = secrets.searx_secret;
        };
      };
    };

    services.nginx.virtualHosts."search.sgiath.dev" = {
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
        proxyPass = "http://127.0.0.1:8080";
      };
    };
  };
}

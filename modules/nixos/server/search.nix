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
        };
        search = {
          safe_search = 0;
          autocomplete = "duckduckgo";
          default_lang = "en-US";
          formats = [
            "html"
            "json"
          ];
          engines = [
            {
              name = "bing";
              engine = "bing";
              disabled = false;
            }
            {
              name = "mojeek";
              engine = "mojeek";
              disabled = false;
            }
            {
              name = "yahoo";
              engine = "yahoo";
              disabled = false;
            }
            {
              name = "qwant";
              engine = "qwant";
              disabled = false;
            }
          ];
        };
        server = {
          bind_address = "127.0.0.1";
          port = 8080;
          base_url = "https://search.sgiath.dev/";
          secret_key = secrets.searx_secret;
          http_protocol_version = "1.1";
        };
        outgoing = {
          request_timeout = 5.0;
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

      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
      };
    };
  };
}

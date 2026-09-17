{
  config,
  lib,
  pkgs,
  ...
}:
let
  nebula = config.sgiath.nebula;
  host = "search.sgiath.dev";
in
{
  config = lib.mkMerge [
    { sgiath.nebula.services = [ "search" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && config.services.searx.enable) {
      sops.secrets.searx_secret.restartUnits = [
        "searx-init.service"
        (if config.services.searx.configureUwsgi then "uwsgi.service" else "searx.service")
      ];
      # The upstream envsubst step does not escape JSON string values.
      systemd.services.searx-init = {
        serviceConfig.LoadCredential = [
          "secret-key:${config.sops.secrets.searx_secret.path}"
        ];
        script = lib.mkForce ''
          umask 077
          ${pkgs.jq}/bin/jq --rawfile secret "$CREDENTIALS_DIRECTORY/secret-key" \
            '.server.secret_key = $secret' \
            ${
              pkgs.writeText "searx-settings.json" (
                builtins.toJSON (builtins.removeAttrs config.services.searx.settings [ "redis" ])
              )
            } \
            > /run/searx/settings.yml
        '';
      };

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
            http_protocol_version = "1.1";
          };
          outgoing = {
            request_timeout = 5.0;
          };
        };
      };

      services.nginx.virtualHosts.${host} = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # Overlay only
        extraConfig = ''
          allow ${nebula.cidr4};
          allow ${nebula.cidr6};
          deny all;
        '';

        locations."/".proxyPass = "http://127.0.0.1:8080";
      };
      systemd.services.nginx.after = [ "searx.service" ];
    })
  ];
}

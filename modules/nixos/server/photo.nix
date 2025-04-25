{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.photoprism.enable) {
    services = {
      photoprism = {
        passwordFile = "/data/photos/password";
        originalsPath = "/data/photos";
        importPath = "/data/photos/imports";

        settings = {
          # authentication
          PHOTOPRISM_ADMIN_USER = "sgiath";
          # feature flags
          PHOTOPRISM_EXPERIMENTAL = "true";
          # customization
          PHOTOPRISM_APP_NAME = "Photo";
          # site info
          PHOTOPRISM_SITE_URL = "https://photo.sgiath.dev/";
          PHOTOPRISM_SITE_AUTHOR = "sgiath";
          # proxy
          PHOTOPRISM_HTTPS_PROXY = "https://photo.sgiath.dev";
          PHOTOPRISM_HTTPS_PROXY_INSECURE = "true";
          PHOTOPRISM_TRUSTED_PROXY = "127.0.0.1";
          # webserver
          PHOTOPRISM_DISABLE_TLS = "true";
        };
      };

      nginx.virtualHosts."photo.sgiath.dev" = {
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
          proxyPass = "http://127.0.0.1:2342";
          proxyWebsockets = true;
        };
      };
    };
  };
}


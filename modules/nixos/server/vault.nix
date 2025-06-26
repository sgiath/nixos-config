{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.vaultwarden.enable) {
    services.vaultwarden.config = {
      DOMAIN = "https://vault.sgiath.dev";
      SIGNUPS_ALLOWED = false;
    
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
    
      ROCKET_LOG = "critical";
    
      # This example assumes a mailserver running on localhost,
      # thus without transport encryption.
      # If you use an external mail server, follow:
      #   https://github.com/dani-garcia/vaultwarden/wiki/SMTP-configuration
      SMTP_HOST = "127.0.0.1";
      SMTP_PORT = 25;
      SMTP_SSL = false;

      SMTP_FROM = "vault@sgiath.dev";
      SMTP_FROM_NAME = "sgiath.dev Vault server";
    };

    services.nginx.virtualHosts."vault.sgiath.dev" = {
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
        proxyPass = "http://127.0.0.1:8222";
      };
    };
  };
}

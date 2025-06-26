{
  config,
  lib,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.vaultwarden.enable) {
    services.vaultwarden.config = {
      DOMAIN = "https://vault.sgiath.dev";
      SIGNUPS_ALLOWED = false;
      ADMIN_TOKEN = secrets.vaultwarden_admin_token;
    
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
    
      ROCKET_LOG = "critical";
    
      # This example assumes a mailserver running on localhost,
      # thus without transport encryption.
      # If you use an external mail server, follow:
      #   https://github.com/dani-garcia/vaultwarden/wiki/SMTP-configuration
      SMTP_HOST = "smtp.protonmail.ch";
      SMTP_PORT = 587;
      # SMTP_SECURITY = "force_tls";
      SMTP_USERNAME = "FilipVavera@sgiath.dev";
      SMTP_PASSWORD = secrets.protonmail_token;

      SMTP_FROM = "FilipVavera@sgiath.dev";
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

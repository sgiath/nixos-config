{
  inputs,
  system,
  config,
  lib,
  ...
}:

{
  config = lib.mkIf (config.sgiath.server.enable && config.services.foundryvtt.enable) {
    services.nginx.virtualHosts."foundry.sgiath.dev" = {
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
        proxyPass = "http://127.0.0.1:30000";
        proxyWebsockets = true;
      };

      locations."/game" = {
        proxyPass = "http://127.0.0.1:30000";
        proxyWebsockets = true;
        extraConfig = ''
          # If we're returning a 302 auth redirect from /game, pass the args
          proxy_intercept_errors on;
          error_page 302 = @join_redirect;
        '';
      };

      extraConfig = ''
        location @join_redirect {
          return 302 /join$is_args$args;
        }
      '';
    };

    services.foundryvtt = {
      hostName = "foundry.sgiath.dev";
      package = inputs.foundryvtt.packages.${system}.foundryvtt_13;
      minifyStaticFiles = true;
      proxySSL = true;
      proxyPort = 443;
      upnp = false;
    };
  };
}

{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.home-assistant.enable) {
    services = {
      nginx = {
        upstreams."home-assistant".servers = {
          address = "localhost:8123";
        };

        virtualHosts."home-assistant.sgiath.dev" = {
          # SSL
          onlySSL = true;
          enableACME = true;
          kTLS = true;

          # QUIC
          http3_hq = true;
          quic = true;

          # static files
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://home-assistant";
            # does not work with X-Forwarded-For
            recommendedProxySettings = false;
            extraConfig = ''
              proxy_set_header        Host $host;
              proxy_set_header        X-Real-IP $remote_addr;
              # proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header        X-Forwarded-Proto $scheme;
              proxy_set_header        X-Forwarded-Host $host;
              proxy_set_header        X-Forwarded-Server $host;
            '';
          };
        };
      };

      home-assistant = {
        config = {
          homeassistant = {
            name = "Home";
            latitude = 49.868068917708214;
            longtitude = 18.133653402327774;
            temperature_unit = "C";
            time_zone = "UTC";
            unit_system = "metric";
          };
        };
      };
    };
  };
}

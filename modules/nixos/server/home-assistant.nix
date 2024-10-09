{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.home-assistant.enable) {
    services = {
      nginx.virtualHosts."home-assistant.sgiath.dev" = {
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
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:8123";
        };
      };

      home-assistant = {
        extraPackages =
          python3Packages: with python3Packages; [
            psycopg2
            gtts
          ];
        config = {
          http = {
            server_host = [ "127.0.0.1" ];
            server_port = 8123;
            use_x_forwarded_for = true;
            trusted_proxies = [
              "127.0.0.1"
              "192.168.1.0/24"
            ];
          };
          homeassistant = {
            name = "Home";
            latitude = 49.868068917708214;
            longitude = 18.133653402327774;
            temperature_unit = "C";
            time_zone = "UTC";
            unit_system = "metric";
          };
        };
      };
    };
  };
}

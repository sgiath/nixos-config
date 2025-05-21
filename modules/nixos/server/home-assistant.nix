{ config, lib, ... }:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
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
            pymetno
          ];
        extraComponents = [
          # custom
          "openweathermap"
          "shelly"
          # "tuya"
          # "tplink"
          # "tplink_tapo"
          "roborock"
          # "starlink"
          # "bitcoin"
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
            latitude = 49.84582092775863;
            longitude = 18.181012180054974;
            temperature_unit = "C";
            time_zone = "UTC";
            unit_system = "metric";
          };

          # default config
          config = { };
          dhcp = { };
          energy = { };
          history = { };
          image_upload = { };
          mobile_app = { };
          ssdp = { };
          sun = { };
          zeroconf = { };
          matrix = {
            homeserver = "https://matrix.sgiath.dev";
            username = "@sgiath:sgiath.dev";
            password = secrets.matrix_password;
            rooms = [
              "#home-assistant:sgiath.dev"
            ];
          };
        };
      };
    };
  };
}

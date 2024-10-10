{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.monitoring = {
    enable = lib.mkEnableOption "monitoring";
  };

  config = lib.mkIf (config.sgiath.server.enable && config.services.monitoring.enable) {
    services = {
      prometheus = {
        enable = true;
        port = 9090;

        exporters = {
          node = {
            enable = true;
            enabledCollectors = [ "systemd" ];
          };
        };

        scrapeConfigs = [
          {
            job_name = "vesta";
            static_configs = [
              { targets = [ "127.0.0.1:9100" ]; }
            ];
          }
        ];
      };

      grafana = {
        enable = true;
        settings = {
          server = {
            root_url = "https://monitoring.sgiath.dev";
          };
        };
      };

      loki = {
        enable = false;
        configuration = {
          server = {
            http_listen_port = 28183;
            grpc_listen_port = 0;
          };

          positions.filename = "/tmp/positions.yaml";

          clients = [
            { url = "http://127.0.0.1:3100/loki/api/v1/push"; }
          ];

          scrape_configs = [
            {
              job_name = "journal";
              journal = {
                max_age = "12h";
                labels = {
                  job = "systemd-journal";
                  host = "vesta";
                };
              };
              relabel_configs = [
                {
                  source_labels = [ "__journal__systemd_unit" ];
                  target_label = "unit";
                }
              ];
            }
          ];
        };
      };

      alloy = {
        enable = true;
      };

      nginx.virtualHosts."monitoring.sgiath.dev" = {
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
          proxyPass = "http://127.0.0.1:3000";
        };
      };
    };
  };
}

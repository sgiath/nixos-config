{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.server.enable {
    security.acme = {
      acceptTerms = true;
      # certs = {
      #   "sgiath.dev" = {
      #     extraDomainNames = [
      #       "5e.sgiath.dev"
      #       "audio.sgiath.dev"
      #       "foundry.sgiath.dev"
      #       "home-assistant.sgiath.dev"
      #       "matrix.sgiath.dev"
      #       "meet.sgiath.dev"
      #       "nas.sgiath.dev"
      #       "osm.sgiath.dev"
      #       "plex.sgiath.dev"
      #       "search.sgiath.dev"
      #       "tak.sgiath.dev"
      #       "wp.sgiath.dev"
      #       "xmpp.sgiath.dev"
      #     ];
      #   };
      # };
      defaults = {
        email = "server@sgiath.dev";
        dnsProvider = "cloudflare";
        credentialFiles = {
          CLOUDFLARE_EMAIL_FILE = "/run/secrets/cloudflare-email";
          CLOUDFLARE_DNS_API_TOKEN_FILE = "/run/secrets/cloudflare-token";
        };
        # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
      };
    };

    services.nginx = {
      enable = true;
      package = pkgs.nginxQuic;
      eventsConfig = ''
        multi_accept on;
        worker_connections 2048;
      '';
      resolver.addresses = [ "127.0.0.1:53" ];

      clientMaxBodySize = "2048M";
      enableQuicBPF = true;
      mapHashBucketSize = 128;
      mapHashMaxSize = 4096;
      serverNamesHashBucketSize = 128;
      serverNamesHashMaxSize = 2048;
      statusPage = true;

      recommendedBrotliSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedZstdSettings = true;
      recommendedProxySettings = true;
      commonHttpConfig = ''
        charset utf-8;
        log_not_found off;
        aio threads;
        directio 4m;

        client_body_buffer_size 1K;
        client_header_buffer_size 1k;

        proxy_headers_hash_max_size 512;
        proxy_headers_hash_bucket_size 64;

        # allow the server to close connection on non responding client, this will free up memory
        reset_timedout_connection on;

        # if client stop responding, free up memory -- default 60
        send_timeout 20;
      '';

      virtualHosts = {
        # default = {
        #   default = true;
        #   locations."/.well-known/acme-challenge/" = {
        #     root = "/var/lib/acme/acme-challenge";
        #     extraConfig = ''
        #       allow all;
        #     '';
        #   };
        # };

        "nas.sgiath.dev" = {
          # SSL
          onlySSL = true;
          enableACME = true;
          kTLS = true;

          # QUIC
          http3_hq = true;
          quic = true;

          locations = {
            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://192.168.1.4:5000";
            };

            "/transmission/" = {
              proxyWebsockets = true;
              proxyPass = "http://192.168.1.4:9091";
            };
          };
        };

        "plex.sgiath.dev" = {
          # SSL
          onlySSL = true;
          enableACME = true;
          kTLS = true;

          # QUIC
          http3_hq = true;
          quic = true;

          locations = {
            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://192.168.1.4:32400";
            };
          };
        };
      };
    };
  };
}

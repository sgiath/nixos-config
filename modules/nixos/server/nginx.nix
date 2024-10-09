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
      defaults = {
        email = "server@sgiath.dev";
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        credentialFiles = {
          CLOUDFLARE_EMAIL_FILE = "/data/secrets/cloudflare-email";
          CLOUDFLARE_DNS_API_TOKEN_FILE = "/data/secrets/cloudflare-token";
        };
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
        "nas.sgiath.dev" = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

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
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

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

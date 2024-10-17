{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable) {
    services = {
      nginx.virtualHosts."sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = false;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        root = "/data/www/sgiath.dev";

        locations = {
          "/profile" = {
            extraConfig = ''
              add_header Access-Control-Allow-Origin '*';
              add_header Cross-Origin-Resource-Policy 'cross-origin';
            '';
          };

          "/presentations" = {
            extraConfig = ''
              rewrite ^/presentations(/index.html)?$ /presentations/ permanent;
              rewrite ^/presentations/(.+)/$ /presentations/$1 permanent;
            '';

            tryFiles = "$uri $uri.html $uri/index.html =404";
          };

          "/download" = {
            extraConfig = ''
              autoindex on;
              autoindex_exact_size off;
              autoindex_format html;
            '';
            tryFiles = "$uri $uri/ $uri.zip $uri/index.html =404";
          };

          "/sgiath.asc" = {
            extraConfig = ''
              add_header Content-Disposition 'attachment';
            '';
          };
        };
      };
    };
  };
}

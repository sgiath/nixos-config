{ config, lib, ... }:
{
  options.services.sgiath-dev.proxy = lib.mkEnableOption "sgiath.dev proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.sgiath-dev.proxy) {
    services = {
      nginx.virtualHosts."sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        root = "/data/www/sgiath.dev";

        extraConfig = ''
          rewrite ^/twitter/?$ https://x.com/SgiathDev redirect;
          rewrite ^/x/?$ https://x.com/SgiathDev redirect;
          rewrite ^/github/?$ https://github.com/sgiath redirect;
          rewrite ^/source-hut/?$ https://sr.ht/~sgiath redirect;

          error_page 404 /404.html;
        '';

        locations = {
          "= /ping".extraConfig = ''
            default_type text/plain;
            return 200 "pong\n";
          '';

          "= /sgiath.asc".extraConfig = ''
            add_header Content-Disposition 'attachment';
          '';

          "/profile".extraConfig = ''
            add_header Access-Control-Allow-Origin '*';
            add_header Cross-Origin-Resource-Policy 'cross-origin';
          '';

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

          "/" = {
            tryFiles = "$uri $uri.html $uri/index.html =404";
          };
        };
      };
    };
  };
}

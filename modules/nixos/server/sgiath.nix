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
          # Tell caches that responses vary by Accept header because the same
          # extensionless URL can serve either HTML or Markdown.
          add_header Vary Accept always;

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

          # Explicit .md URLs always serve as Markdown.
          "~* \\.md$" = {
            extraConfig = ''
              default_type text/markdown;
            '';
          };

          # Explicit .html URLs honor Accept: text/markdown by rewriting to the
          # sibling .md file; otherwise they serve HTML normally.
          "~* \\.html$" = {
            extraConfig = ''
              add_header Vary Accept always;
              if ($page_ext = ".md") {
                rewrite ^(.*)\.html$ $1.md last;
              }
            '';
          };

          # Negotiate the root path: prefer index.md when Accept includes
          # text/markdown, otherwise fall back to index.html.
          "= /" = {
            extraConfig = ''
              include /data/www/sgiath.dev/_nginx_link_headers*.conf;
              default_type text/markdown;
              try_files /index$page_ext /index.html =404;
            '';
          };

          # Negotiate extensionless page URLs: try the negotiated extension
          # (.md or .html), then the .html file, then index.html.
          # default_type is text/markdown so that .md files served for
          # extensionless URLs get the right Content-Type.
          "/" = {
            extraConfig = ''
              default_type text/markdown;
              try_files $uri $uri$page_ext $uri.html $uri/index.html =404;
            '';
          };
        };
      };
    };
  };
}

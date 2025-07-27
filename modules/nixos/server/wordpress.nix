{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.wordpress.proxy = lib.mkEnableOption "Wordpress proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.wordpress.proxy) {
    virtualisation.oci-containers.containers.romana = {
      image = "romana-vaverova:latest";
      imageFile = pkgs.dockerTools.buildImage {
        name = "romana-vaverova";
        tag = "latest";

        fromImageName = "wordpress";
        fromImageTag = "6.8.2-php8.4-apache";

        runAsRoot = ''
          apt-get update && apt-get install -y libxml2-dev
          docker-php-ext-install soap
        '';
      };

      ports = [ "80:8081" ];
      volumes = [ "/data/www/romana-vaverova.cz:/var/www/html" ];
      extraOptions = [ "--network=host" ];
      environment = {
        WORDPRESS_DB_USER = "wordpress";
        WORDPRESS_DB_NAME = "romana-vaverova";
        WORDPRESS_DB_HOST = "localhost";
        WORDPRESS_DB_PASSWORD = "wordpress";
      };
    };

    services = {
      mysql = {
        enable = true;
        ensureDatabases = [ "romana-vaverova" ];
        ensureUsers = [
          {
            name = "wordpress";
            password = "wordpress";
            ensurePermissions = { "romana-vaverova.*" = "ALL PRIVILEGES"; };
          }
        ];
      };

      nginx.virtualHosts."romana.sgiath.dev" = {
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
          proxyPass = "http://127.0.0.1:8081";
        };
      };
    };
  };
}

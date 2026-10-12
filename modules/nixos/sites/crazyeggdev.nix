{ config, lib, ... }:
let
  # ce-local-infra's mkcert certificate, copied from its nginx/crazyegg/
  # directory. It is a runtime file (nginx cannot read the home checkout);
  # never put it in the Nix store or SOPS.
  certificateDir = "/var/lib/crazyeggdev-tls";
in
{
  # Local CrazyEgg development: *.crazyeggdev.com resolves to 127.0.0.1, so the
  # system nginx owns port 443 and hands those names to ce-local-infra's
  # dev-nginx, published on 127.0.0.1:8443 by a compose override.
  config = lib.mkIf (config.sgiath.roles.server.enable && config.sgiath.sites.crazyeggdev.enable) {
    # setgid keeps copied files in the nginx group.
    systemd.tmpfiles.rules = [ "d ${certificateDir} 2750 sgiath nginx -" ];

    services.nginx = {
      # A variable in the certificate path makes nginx load it per handshake, so a
      # missing certificate fails these names instead of every vhost at startup.
      appendHttpConfig = ''
        map "" $crazyeggdev_certificate {
          default development;
        }
      '';

      virtualHosts."crazyeggdev.com" = {
        serverAliases = [
          "*.crazyeggdev.com"
          "crazyeggproxydev.com"
          "*.crazyeggproxydev.com"
        ];

        onlySSL = true;
        sslCertificate = "${certificateDir}/$crazyeggdev_certificate.cert.pem";
        sslCertificateKey = "${certificateDir}/$crazyeggdev_certificate.key.pem";

        locations."/" = {
          proxyPass = "https://127.0.0.1:8443";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_ssl_server_name on;
            proxy_ssl_name $host;

            allow 127.0.0.1;
            allow ::1;
            deny all;
          '';
        };
      };
    };
  };
}

{ config, lib, ... }:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  options.services.pi-hole.enable = lib.mkEnableOption "pi-hole";

  config = lib.mkIf (config.sgiath.server.enable && config.services.pi-hole.enable) {
    networking.networkmanager.dns = lib.mkForce "none";

    services.nginx = {
      virtualHosts."dns.sgiath" = {
        rejectSSL = true;
        locations = {
          "= /".return = "301 /admin/";
          "/" = {
            proxyPass = "http://127.0.0.1:8053";
            extraConfig = ''
              allow 127.0.0.1;
              allow ::1;
              deny 192.168.1.1;
              allow 192.168.1.0/24;
              deny all;
            '';
          };
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    virtualisation.oci-containers.containers.pihole = {
      image = "pihole/pihole:2026.02.0";
      ports = [
        "53:53/tcp"
        "53:53/udp"
        "127.0.0.1:8053:8053/tcp"
      ];
      volumes = [
        "/var/lib/pihole:/etc/pihole"
      ];
      extraOptions = [
        "--network=host"
      ];
      environment = {
        TZ = "UTC";
        FTLCONF_webserver_port = "8053";
        FTLCONF_webserver_api_password = secrets.pihole-password;
      };
    };
  };
}

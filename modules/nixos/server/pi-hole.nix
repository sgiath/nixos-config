{ config, lib, ... }:
{
  options.services.pi-hole.enable = lib.mkEnableOption "pi-hole";

  config = lib.mkIf (config.sgiath.server.enable && config.services.pi-hole.enable) {
    networking.networkmanager.dns = lib.mkForce "none";

    services.nginx = {
      virtualHosts."dns.sgiath" = {
        rejectSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:8053";
        extraConfig = ''
          location = / {
            return 301 /admin/;
          }
        '';
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    virtualisation.oci-containers.containers.pihole = {
      image = "pihole/pihole:2025.04.0";
      ports = [
        "53:53/tcp"
        "53:53/udp"
        "80:8053/tcp"
        "443:8054/tcp"
      ];
      volumes = [
        "/var/lib/pihole:/var/lib/pihole"
        "dnsmasq:/etc/dnsmasq.d"
      ];
      extraOptions = [
        "--network=host"
      ];
      environment = {
        FTLCONF_webserver_api_password = "";
        TZ = "UTC";
      };
    };
  };
}

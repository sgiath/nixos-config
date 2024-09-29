{ config, lib, ... }:
{
  options.services.pi-hole = {
    enable = lib.mkEnableOption "pi-hole";
  };

  config = lib.mkIf (config.sgiath.server.enable && config.services.pi-hole.enable) {
    services.nginx = {
      upstreams."pi-hole".servers = {
        address = "localhost:8053";
      };

      virtualHosts."dns.sgiath" = {
        rejectSSL = true;
        locations."/".proxyPass = "http://pi-hole";
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
      image = "pihole/pihole:2024.07.0";
      volumes = [
        "pihole:/etc/pihole"
        "dnsmasq:/etc/dnsmasq.d"
      ];
      extraOptions = [
        "--network=host"
      ];
      environment = {
        WEB_PORT = "8053";
        TZ = "UTC";
      };
    };
  };
}

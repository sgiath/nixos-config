{ config, lib, ... }:
{
  options.sgiath.roles.laptop.enable = lib.mkEnableOption "notebook role";

  config = lib.mkIf config.sgiath.roles.laptop.enable {
    # The Pi-holes over Nebula first, then the network's own DNS from DHCP:
    # hotel captive portals answer only through their resolver until you log
    # in, and the tunnel comes up only after that. While it is down each
    # lookup waits out the Pi-hole timeouts (1 s each) before falling through.
    networking.resolvconf = {
      extraConfig = ''
        name_servers="${lib.concatStringsSep " " config.sgiath.nebula.resolvers}"
      '';
      extraOptions = [
        "timeout:1"
        "attempts:1"
      ];
    };
    networking.networkmanager = {
      enable = lib.mkForce true;
      settings.connectivity = {
        enabled = true;
        uri = "http://nmcheck.gnome.org/check_network_status.txt";
        response = "NetworkManager is online";
        interval = 60;
      };
    };

    # Foreign networks (hotels) reach nothing; peers come in over Nebula,
    # whose own firewall admits only trusted certificates.
    networking.firewall = {
      enable = lib.mkForce true;
      trustedInterfaces = [ config.services.nebula.networks.sgiath.tun.device ];
    };
    services.openssh.openFirewall = false;
  };
}

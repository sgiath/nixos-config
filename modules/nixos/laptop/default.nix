{ config, lib, ... }:
{
  options.sgiath.roles.laptop.enable = lib.mkEnableOption "notebook role";

  config = lib.mkIf config.sgiath.roles.laptop.enable {
    # DNS comes from DHCP: hotel and other captive portals only answer through
    # their own resolver until you log in.
    networking.networkmanager = {
      enable = lib.mkForce true;
      settings.connectivity = {
        enabled = true;
        uri = "http://nmcheck.gnome.org/check_network_status.txt";
        response = "NetworkManager is online";
        interval = 60;
      };
    };
  };
}

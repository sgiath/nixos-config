{ config, lib, ... }:

{
  options.sgiath.networking.localDNS = {
    enable = lib.mkEnableOption "local DNS";
  };

  config = {
    networking = {
      hosts = {
        "192.168.1.2" = [ "sgiath.dev" "dns.sgiath" ];
        "192.168.1.3" = [ "sgiath.dev" "dns.sgiath" ];
        "192.168.1.4" = [ "nas.sgiath" ];
        "192.168.1.5" = [ "nas.sgiath" ];
        "192.168.1.150" = [ "mix.sgiath" ];
      };
      nameservers = [
        "192.168.1.2"
      ];
      networkmanager.enable = true;
      firewall.enable = false;
    };
  };
}

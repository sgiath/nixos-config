{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.enable {
    networking = {
      hosts = {
        "192.168.1.1" = [ "router.sgiath" ];
        "192.168.1.3" = [
          "vesta.sgiath.dev"
          "niamh.sgiath.dev"
          "dns.sgiath"
        ];
        "192.168.1.4" = [ "nas.sgiath" ];
        "192.168.1.5" = [ "nas.sgiath" ];
      };
      networkmanager.enable = false;
      resolvconf.enable = lib.mkForce false;
      dhcpcd.extraConfig = "nohook resolv.conf";
      firewall.enable = false;
    };
    environment.etc."resolv.conf".text = ''
      search sgiath.dev

      nameserver 192.168.1.3
      nameserver 192.168.1.1
      nameserver 1.1.1.1
      nameserver 8.8.8.8
    '';

    users.users.sgiath.extraGroups = [ "networkmanager" ];
  };
}

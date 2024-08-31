{ config, lib, userSettings, ... }:

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

      resolved.enable = false;
      resolvconf.enable = lib.mkForce false;
      dhcpcd.extraConfig = "nohook resolv.conf";
      networkmanager = {
        enable = true;
        dns = "none";
      };
      firewall.enable = false;
    };
    environment.etc."resolv.conf".text =
      if config.sgiath.networking.localDNS.enable then
        "nameserver 192.168.1.2\n"
      else
        "nameserver 8.8.8.8\nnameserver 8.8.4.4\n";

    users.users.${userSettings.username}.extraGroups = [ "networkmanager" ];
  };
}

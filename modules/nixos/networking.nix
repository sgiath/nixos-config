{
  config,
  lib,
pkgs,
  userSettings,
  ...
}:

{
  config = lib.mkIf config.sgiath.enable {
    environment.systemPackages = with pkgs; [ wpa_supplicant_gui ];
    networking = {
      wireless = {
        enable = true;
        userControlled.enable = true;
        networks = {
          Starlink = {
            priority = 10;
            pskRaw = "694358f6d79f35d6feac9f1aefe7615b17bef5c09542858018f7a44f117e3502";
          };
          Starlink2 = {
            priority = 0;
            pskRaw = "5ece5655aaf9756e003716758313ba676cad380f17492761dcb491605018de9c";
          };
        };
      };
      hosts = {
        "192.168.1.1" = [ "router.sgiath" ];
        "192.168.1.2" = [
          "sgiath.dev"
          "dns.sgiath"
        ];
        "192.168.1.3" = [
          "sgiath.dev"
          "dns.sgiath"
        ];
        "192.168.1.4" = [ "nas.sgiath" ];
        "192.168.1.5" = [ "nas.sgiath" ];
        "192.168.1.150" = [ "mix.sgiath" ];
      };

      resolvconf.enable = lib.mkForce false;
      dhcpcd.extraConfig = "nohook resolv.conf";
      firewall.enable = false;
    };
    environment.etc."resolv.conf".text = ''
      search sgiath.dev

      nameserver 192.168.1.2
      nameserver 192.168.1.1
      nameserver 8.8.8.8
    '';

    users.users.${userSettings.username}.extraGroups = [ "networkmanager" ];
  };
}

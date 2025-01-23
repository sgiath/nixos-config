{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.enable {
    networking = {
      wireless = {
        userControlled.enable = true;
        networks = {
          Starlink = {
            priority = 10;
            pskRaw = "694358f6d79f35d6feac9f1aefe7615b17bef5c09542858018f7a44f117e3502";
          };
        };
      };
      hosts = {
        "192.168.1.1" = [ "router.sgiath" ];
        "192.168.1.2" = [
          "vesta.sgiath.dev"
          "dns.sgiath"

          "sgiath.dev"
          "5e.sgiath.dev"
          "foundry.sgiath.dev"
          "search.sgiath.dev"
          "audio.sgiath.dev"
          "meet.sgiath.dev"
          "matrix.sgiath.dev"
          "n8n.sgiath.dev"
          "open-webui.sgiath.dev"
          "home-assistant.sgiath.dev"
        ];
        "192.168.1.4" = [ "nas.sgiath" ];
        "192.168.1.5" = [ "nas.sgiath" ];
        "192.168.1.150" = [ "mix.sgiath" ];
      };

      networkmanager.enable = false;
      resolvconf.enable = lib.mkForce false;
      dhcpcd.extraConfig = "nohook resolv.conf";
      firewall.enable = false;
    };
    environment.etc."resolv.conf".text = ''
      search sgiath.dev

      nameserver 192.168.1.2
      nameserver 192.168.1.1
      nameserver 1.1.1.1
      nameserver 8.8.8.8
    '';

    users.users.sgiath.extraGroups = [ "networkmanager" ];
  };
}

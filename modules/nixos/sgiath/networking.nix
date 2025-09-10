{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.enable {
    networking = {
      wireless = {
        enable = false;
        allowAuxiliaryImperativeNetworks = true;
        # wpa_passphrase ssid psk
        networks = {
          # home WiFi
          "Turris 5" = {
            pskRaw = "5979f534aeb44615c6efa716ad68f0bf36747981e4eb1a83381997c03301eb44";
            priority = 9;
          };
          "Turris 2" = {
            pskRaw = "70130aabbf56025a53266182e3a282588d7c324c90f4e75e45fff5a275ba019a";
            priority = 5;
          };
          # mobile hotspot
          "sgiath" = {
            pskRaw = "f6a123fbdb7740477934a8a5fb8c3e4ef6496c5e0fefd43f0074559fc5345c7c";
            priority = 10;
          };
          # Kypruv mlyn
          "mlyn" = {
            pskRaw = "e4b2f70b2546be145714c58c42b6f0d725b4df7b5d06dbc77bd439157ca7147f";
            priority = 5;
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
          "ai.sgiath.dev"
          "home-assistant.sgiath.dev"
          "mollysocket.sgiath.dev"
          "focalboard.sgiath.dev"
          "auth.sgiath.dev"
          "osm.sgiath.dev"
          "photo.sgiath.dev"
          "watch.sgiath.dev"
          "torrent.sgiath.dev"
          "minecraft.sgiath.dev"
        ];
        "192.168.1.4" = [ "nas.sgiath" ];
        "192.168.1.5" = [ "nas.sgiath" ];
        "192.168.1.150" = [ "mix.sgiath" ];
      };

      networkmanager.enable = true;
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

{ config, lib, ... }:
let
  # secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  config = lib.mkIf config.sgiath.enable {
    networking = {
      # https://account.proton.me/u/4/vpn/WireGuard
      wireguard.interfaces = {
        wg0 = {
          # privateKey = secrets.proton_vpn;
          ips = ["10.2.0.2/32"];
          peers = [
            {
              name = "CZ-36";
              endpoint = "146.70.129.18:51820";
              publicKey = "sDVKmYDevvGvpKNei9f2SDbx5FMFi6FqBmuRYG/EFg8=";
              allowedIPs = ["0.0.0.0/0"];
            }
          ];
        };
      };
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
          "ai.sgiath.dev"
          "home-assistant.sgiath.dev"
          "mollysocket.sgiath.dev"
          "focalboard.sgiath.dev"
          "auth.sgiath.dev"
          "osm.sgiath.dev"
          "photo.sgiath.dev"
          "plex.sgiath.dev"
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

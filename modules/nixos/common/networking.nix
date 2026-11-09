{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.enable (
    lib.mkMerge [
      {
        networking = {
          hosts = {
            "192.168.1.1" = [ "router.sgiath" ];
            # Pi-hole web UI, reached over Nebula wherever the host is.
            ${config.sgiath.nebula.peers.vesta.ip4} = [ "dns.sgiath" ];
            "192.168.1.11" = [ "juno1.sgiath" ];
          };
          firewall.enable = false;
          resolvconf.enable = lib.mkForce false;
        };

        users.users.sgiath.extraGroups = [ "networkmanager" ];
      }

      (lib.mkIf config.networking.networkmanager.enable {
        networking.networkmanager.wifi.powersave = false;
        systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
      })

      (lib.mkIf (!config.networking.networkmanager.enable) {
        networking = {
          defaultGateway = "192.168.1.1";
          dhcpcd = {
            denyInterfaces = [
              "veth*"
              "docker*"
              "br-*"
            ];
            extraConfig = "nohook resolv.conf";
          };
        };

        # Pi-hole over Nebula first; public resolvers answer within a second
        # while the tunnel is down. Hosts with a fixed home LAN address
        # override the list to reach Pi-hole without the tunnel. glibc reads
        # at most three nameservers.
        networking.nameservers = lib.mkDefault [
          config.sgiath.nebula.peers.vesta.ip4
          "1.1.1.1"
          "8.8.8.8"
        ];
        environment.etc."resolv.conf".text = ''
          search sgiath.dev
          options timeout:1 attempts:1

          ${lib.concatMapStrings (ns: "nameserver ${ns}\n") config.networking.nameservers}'';
      })
    ]
  );
}

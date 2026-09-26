{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  services.fstrim.enable = true;

  networking = {
    # DHCP stays on for the other ports so the box is reachable even if the
    # RJ45 name below turns out different on this unit.
    interfaces = {
      # 10 GbE Realtek RTL8127 (r8127). The ConnectX-7 QSFP ports
      # (enp1s0f*np*, enP2p1s0f*np*) stay unconfigured until a second Spark exists.
      enP7s7 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.1.11";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = "fd39:f21:ea9::11";
            prefixLength = 64;
          }
        ];
      };
    };
  };

  nixpkgs.hostPlatform = "aarch64-linux";
}

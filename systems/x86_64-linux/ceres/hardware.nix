{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    ./disko.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      kernelModules = [
        "atlantic"
        "igc"
      ];
      availableKernelModules = [
        "nvme"
        "thunderbolt"
        "xhci_pci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
    };
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
    kernelParams = [ "amd_pstate=active" ];

    # Docker and Podman create and delete host-side veths constantly. Each
    # kernel-generated link-local address on them makes Chromium report a
    # network change (ERR_NETWORK_CHANGED in open tabs). New interfaces get
    # no automatic IPv6 addresses; the ports in networking.interfaces keep
    # link-local and SLAAC. Explicit addresses (Nebula, the static ULAs) are
    # unaffected.
    kernel.sysctl = {
      "net.ipv6.conf.default.addr_gen_mode" = 1;
    }
    // lib.mapAttrs' (
      name: _: lib.nameValuePair "net.ipv6.conf.${name}.addr_gen_mode" 0
    ) config.networking.interfaces;

    # Windows 11 boot
    # loader.systemd-boot.edk2-uefi-shell.enable = true;
    loader.systemd-boot.windows."11".efiDeviceHandle = "HD1b";
  };

  services = {
    nfs.server.enable = false;
    # The btrfs root mounts with the kernel's default discard=async, so a
    # weekly fstrim only re-trims unallocated space (13 min, 325 GiB).
    fstrim.enable = false;
  };

  networking = {
    useDHCP = false;
    interfaces = {
      # 10G Aquantia, atlantic
      enp57s0 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.1.6";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = "fd39:f21:ea9::6";
            prefixLength = 64;
          }
        ];
      };

      # 2.5G Intel I225-V, igc
      enp59s0 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.1.7";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = "fd39:f21:ea9::7";
            prefixLength = 64;
          }
        ];
      };
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

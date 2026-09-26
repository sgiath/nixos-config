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
    # AMD Zen sensors
    extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    kernelParams = [ "amd_pstate=active" ];

    # Windows 11 boot
    # loader.systemd-boot.edk2-uefi-shell.enable = true;
    loader.systemd-boot.windows."11".efiDeviceHandle = "HD1b";
  };

  services = {
    nfs.server.enable = false;
    fstrim.enable = true;
  };

  sgiath.nas.enable = true;

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

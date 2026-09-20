{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernelModules = [ "kvm-amd" ];
  # AMD Zen sensors
  boot.extraModulePackages = [ config.boot.kernelPackages.zenpower ];

  # Headless Mesa/VA-API support for Jellyfin on the Ryzen 5700G iGPU.
  hardware.graphics.enable = true;

  services = {
    nfs.server.enable = false;
    fstrim.enable = true;
  };

  sgiath.nas.enable = true;
  fileSystems = {
    "/data" = {
      device = "/dev/disk/by-uuid/f87c6afb-7e94-452a-a6d7-8e5fc2cf43fb";
      fsType = "ext4";
    };
    "/data2" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };
    "/data3" = {
      device = "/dev/sdb1";
      fsType = "ext4";
    };
  };

  networking = {
    defaultGateway6.interface = "enp1s0";
    interfaces = {
      # 10 Gbps
      enp1s0 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.1.2";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = "fd39:f21:ea9::2";
            prefixLength = 64;
          }
        ];
      };

      # 2.5 Gbps
      enp7s0 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "192.168.1.3";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = "fd39:f21:ea9::3";
            prefixLength = 64;
          }
        ];
      };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

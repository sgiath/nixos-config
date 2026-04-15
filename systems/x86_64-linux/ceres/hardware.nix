{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    ./disko.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "thunderbolt"
      "xhci_pci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    extraModulePackages = [ ];
    kernelParams = [ "amd_pstate=active" ];

    # Windows 11 boot
    # loader.systemd-boot.edk2-uefi-shell.enable = true;
    loader.systemd-boot.windows."11".efiDeviceHandle = "HD1b";
  };

  services = {
    nfs.server.enable = false;
    fstrim.enable = true;
  };

  fileSystems = {
    "/nas/homes" = {
      device = "192.168.1.4:/volume1/homes";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
      ];
    };

    "/nas/movies" = {
      device = "192.168.1.4:/volume1/Movies";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
      ];
    };

    "/nas/series" = {
      device = "192.168.1.4:/volume1/Series";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
      ];
    };

    "/nas/downloads" = {
      device = "192.168.1.4:/volume1/Downloads";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
      ];
    };
  };

  networking = {
    defaultGateway6.interface = "enp57s0";
    interfaces = {
      # 10 Gbps
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

      # 2.5 Gbps
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

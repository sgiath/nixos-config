{
  config,
  lib,
  modulesPath,
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
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  services = {
    nfs.server.enable = true;
    fstrim.enable = true;
  };

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
    "/nas/downloads" = {
      device = "192.168.1.4:/volume1/Downloads";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
      ];
    };
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
  };

  networking.interfaces = {
    # 10 Gbps
    enp1s0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.1.2";
          prefixLength = 24;
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
    };
  };
  boot.kernel.sysctl = {
    "net.ipv6.conf.enp1s0.accept_ra" = 2;
    "net.ipv6.conf.enp7s0.accept_ra" = 2;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

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
    "/nas/homes" = {
      device = "192.168.1.4:/volume1/homes";
      fsType = "nfs";
    };
  };

  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp7s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

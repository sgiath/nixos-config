{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    # (import ./disko.nix { device = "/dev/nvme1n1"; })
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
  };

  services = {
    nfs.server.enable = true;
    fstrim.enable = true;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/c127f369-d1dc-4cfb-827e-3db9dd9ddde5";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/5BB4-78C7";
      fsType = "vfat";
    };

    "/nas/homes" = {
      device = "192.168.1.4:/volume1/homes";
      fsType = "nfs";
    };
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/a09c60a8-7855-42ff-b9b0-73f7c8b8fb4c"; } ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp56s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp58s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp57s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

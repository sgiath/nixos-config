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
  };

  services = {
    nfs.server.enable = true;
    fstrim.enable = true;
  };

  fileSystems = {
    "/nas/homes" = {
      device = "192.168.1.4:/volume1/homes";
      fsType = "nfs";
    };

    "/nas/movies" = {
      device = "192.168.1.4:/volume1/Movies";
      fsType = "nfs";
    };

    "/nas/series" = {
      device = "192.168.1.4:/volume1/Series";
      fsType = "nfs";
    };
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp56s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp58s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp57s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

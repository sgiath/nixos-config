{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  hardware.nvidia.prime = {
    sync.enable = true;
    amdgpuBusId = "PCI:101:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    extraModulePackages = [ ];
    kernelModules = [ "kvm-amd" ];
  };

  services.nfs.server.enable = true;

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/fa2b3be5-2c67-430e-9a96-4872f006c87f";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/FDD7-48C9";
      fsType = "vfat";
    };

    # "/nas/homes" = {
    #   device = "192.168.1.4:/volume1/homes";
    #   fsType = "nfs";
    # };
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/72100ef2-5b3d-4210-82c8-30de00b05fc0"; } ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp3s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

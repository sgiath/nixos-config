{ config, pkgs, userSettings, ... }:

{
  imports = [
    # default values
    ../system.nix

    # hardware
    ./hardware.nix

    # modules
    ../../system/x11.nix
    ../../system/sound.nix
    ../../system/printing.nix
    ../../system/gaming.nix
    ../../system/bluetooth.nix
  ];

  networking.hostName = "pallas";

  # razer notebook specific packages
  environment.systemPackages = with pkgs; [
    razergenie
    openrazer-daemon
  ];

  # Nvidia and AMD GPUs
  hardware.opengl = {
    enable = true;
    driSupport = true;
  };
  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    prime = {
      sync.enable = true;
      amdgpuBusId = "PCI:101:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Razer
  hardware.openrazer = {
    enable = true;
    users = [ userSettings.username ];
  };
}

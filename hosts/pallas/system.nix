{ config, pkgs, userSettings, ... }:

{
  imports = [
    # hardware
    ./hardware.nix

    # modules
    ../../nixos
    ../../nixos/x11.nix
    ../../nixos/sound.nix
    ../../nixos/printing.nix
    ../../nixos/gaming.nix
    ../../nixos/bluetooth.nix
  ];

  networking.hostName = "pallas";

  sgiath = {
    audio.enable = true;
    bluetooth.enable = true;
    printing.enable = true;
    gaming.enable = true;
    x11.enable = true;
  };

  # monitor config
  services.xserver = {
    videoDrivers = [ "amdgpu" "nvidia" ];
    resolutions = [{
      x = 2560;
      y = 1440;
    }];
  };

  # razer notebook specific packages
  environment.systemPackages = with pkgs; [ razergenie openrazer-daemon ];

  # Nvidia and AMD GPUs
  hardware.opengl = {
    enable = true;
    driSupport = true;
  };
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

  # Docker
  virtualisation.docker = { enable = true; };
}

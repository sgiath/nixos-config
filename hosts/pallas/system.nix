{
  config,
  pkgs,
  userSettings,
  ...
}:

{
  imports = [
    # hardware
    ./hardware.nix

    # modules
    ../../nixos
  ];

  networking.hostName = "pallas";

  sgiath = {
    nvidia-gpu.enable = true;
    audio.enable = true;
    bluetooth.enable = true;
    printing.enable = true;
    gaming.enable = true;
    wayland.enable = true;
  };

  # razer notebook specific packages
  environment.systemPackages = with pkgs; [
    razergenie
    openrazer-daemon
  ];

  # Razer
  hardware.openrazer = {
    enable = true;
    users = [ userSettings.username ];
  };

  # Docker
  virtualisation.docker.enable = true;
}

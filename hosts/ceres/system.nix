{ userSettings, ... }:
{
  imports = [ ./hardware.nix ];

  networking.hostName = "ceres";
  users.${userSettings.username} = import ./home.nix;

  sgiath = {
    enable = true;
    gpu = "amd";
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    xamond.enable = true;
    printing.enable = true;
    razer.enable = false;
    wayland.enable = true;
  };

  crazyegg.enable = true;
}

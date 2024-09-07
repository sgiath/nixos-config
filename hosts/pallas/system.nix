{ userSettings, ... }:
{
  imports = [ ./hardware.nix ];

  networking.hostName = "pallas";
  users.${userSettings.username} = import ./home.nix;

  sgiath = {
    enable = true;
    gpu = "nvidia";
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    xamond.enable = true;
    printing.enable = true;
    razer.enable = true;
    wayland.enable = true;
  };

  crazyegg.enable = true;
}

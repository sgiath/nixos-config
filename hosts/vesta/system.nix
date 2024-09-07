{ userSettings, ... }:
{
  imports = [ ./hardware.nix ];

  networking.hostName = "vesta";
  users.${userSettings.username} = import ./home.nix;

  sgiath = {
    enable = true;
    audio.enable = false;
    bluetooth.enable = false;
    docker.enable = true;
    xamond.enable = false;
    printing.enable = false;
    razer.enable = false;
    wayland.enable = false;
  };
}

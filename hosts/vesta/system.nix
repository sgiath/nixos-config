{
  imports = [ ./hardware.nix ];

  home-manager.users.sgiath = import ./home.nix;

  networking.hostName = "vesta";

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

  services.wyoming.faster-whisper.servers = {
    "home-assistant" = {
      enable = true;
      beamSize = 5;
      model = "large-v3";
      language = "auto";
    };
  };
}

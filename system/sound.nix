{ config, nix-gaming, ... }:

{
  imports = [
    nix-gaming.nixosModules.pipewireLowLatency
  ];

  # realtime audio
  security.rtkit.enable = true;

  sound.enable = true;
  hardware.pulseaudio.enable = false;

  # configure pipewire
  services.pipewire = {
    enable = true;

    alsa.enable = true;
    pulse.enable = true;

    lowLatency = {
      enable = true;
      quantum = 64;
      rate = 48000;
    };
  };
}

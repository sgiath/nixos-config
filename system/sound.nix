{ config, nix-gaming, ... }:

{
  imports = [
    nix-gaming.nixosModules.pipewireLowLatency
  ];

  # realtime audio
  security.rtkit.enable = true;

  # pipewire misbehaves when enabled
  # sound.enable = false;
  # hardware.pulseaudio.enable = false;

  # configure pipewire
  services.pipewire = {
    enable = true;
    # audio.enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };

    pulse.enable = true;
    # jack.enable = true;
    # wireplumber.enable = true;

    lowLatency = {
      enable = true;
      quantum = 64;
      rate = 48000;
    };
  };
}

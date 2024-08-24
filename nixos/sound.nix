{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];

  options.sgiath.audio = {
    enable = lib.mkEnableOption "audio";
  };

  config = lib.mkIf config.sgiath.audio.enable {

    # realtime audio
    security.rtkit.enable = true;

    hardware.pulseaudio.enable = false;

    # configure pipewire
    services.pipewire = {
      enable = true;

      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;

      lowLatency = {
        enable = true;
        quantum = 64;
        rate = 48000;
      };
    };
  };
}

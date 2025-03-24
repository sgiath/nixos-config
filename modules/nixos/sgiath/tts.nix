{ lib, config, ... }:
{
  options.services.tts.enable = lib.mkEnableOption "Local TTS";

  config = lib.mkIf config.services.tts.enable {
    services.tts.servers.default = {
      enable = true;
      port = 5000;
      useCuda = false;
      # model = "";
    };
  };
}

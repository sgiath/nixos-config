{lib, config, pkgs, ...}:
{
  options.services.tts.enable = lib.mkEnableOption "Local TTS";

  config = lib.mkIf config.services.tts.enable {
    # environment.systemPackages = [
    #   pkgs.tts
    # ];

    services.tts.servers.default = {
      enable = true;
      port = 5000;
      useCuda = false;
      # model = "";
    };
  };
}

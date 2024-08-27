{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.programs.davinci = {
    enable = lib.mkEnableOption "DaVinci Resolve";
  };

  config = lib.mkIf config.programs.davinci.enable {
    home.packages = with pkgs; [
      davinci-resolve-studio
      vlc

      # audio convertor
      (writeShellScriptBin "convert-audio" ''
        for i in *.mp4; do
          ${ffmpeg}/bin/ffmpeg -i "$i" -c:v copy -c:a pcm_s32le "''${i%.*}.mov"
        done
      '')
    ];
  };
}

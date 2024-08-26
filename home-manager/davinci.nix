{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.davinci = {
    enable = lib.mkEnableOption "DaVinci Resolve";
  };

  config = lib.mkIf config.sgiath.davinci.enable {
    home.packages = with pkgs; [
      davinci-resolve-studio

      # audio convertor
      (writeShellScriptBin "convert-audio" ''
        ${ffmpeg}/bin/ffmpeg -i *.mp4 -c:v copy -c:a pcm_s321e output.mov
      '')
    ];
  };
}

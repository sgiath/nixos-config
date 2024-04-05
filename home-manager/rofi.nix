{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.rofi = {
    enable = lib.mkEnableOption "rofi";
  };

  config = lib.mkIf config.sgiath.rofi.enable {
    programs = {
      rofi = {
        enable = true;
        terminal = "${pkgs.wezterm}/bin/wezterm";
        extraConfig = {
          modi = "window,ssh,drun,filebrowser";
          drun-show-actions = true;
          display-drun = "";
        };
      };
    };
  };
}

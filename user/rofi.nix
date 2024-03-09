{ config, pkgs, ... }:

{
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
}

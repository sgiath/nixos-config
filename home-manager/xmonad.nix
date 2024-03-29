{ config, lib, pkgs, ... }:

{
  options.sgiath.xmonad = { enable = lib.mkEnableOption "xmonad"; };

  config = lib.mkIf config.sgiath.xmonad.enable {
    home.packages = [ pkgs.nitrogen pkgs.cinnamon.nemo-with-extensions ];
    xsession = {
      enable = true;

      windowManager.xmonad = {
        enable = true;
        enableContribAndExtras = true;
        config = ./xmonad/xmonad.hs;
        libFiles."Colors.hs" = ./xmonad/lib/Colors/Yoru.hs;
      };
    };

    services.dunst = {
      enable = true;
      iconTheme = {
        name = "Paper";
        package = pkgs.paper-icon-theme;
      };
    };
    services.flameshot.enable = true;
  };
}

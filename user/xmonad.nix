{ config, ... }:

{
  xsession = {
    enable = true;

    windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;
      config = ./xmonad/xmonad.hs;
      libFiles = {
        "Colors.hs" = ./xmonad/lib/Colors/Yoru.hs;
      };
    };
  };

  services.flameshot.enable = true;
}

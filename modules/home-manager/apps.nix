{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.apps = {
    enable = lib.mkEnableOption "graphical apps";
  };

  config = lib.mkIf config.sgiath.apps.enable {
    home.packages = with pkgs; [
      xfce.thunar
      obsidian
      webcord
      telegram-desktop
      signal-desktop-beta
      gimp

      vscodium-fhs

      betaflight-configurator
      bisq-desktop
      trezor-suite
      trezor-udev-rules
    ];

    programs = {
      hexchat.enable = true;
      obs-studio.enable = true;
    };
  };
}

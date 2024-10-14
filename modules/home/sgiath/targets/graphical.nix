{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.targets.graphical = lib.mkEnableOption "graphical target";

  config = lib.mkIf (config.sgiath.targets.graphical) {
    home.packages = with pkgs; [
      # utils
      xfce.thunar
      vscodium-fhs
      obsidian
      gimp

      # comm
      webcord
      telegram-desktop
      signal-desktop-beta
      cinny-desktop
      simplex-chat-desktop

      # bitcoin
      # bisq-desktop
      trezor-suite
      trezor-udev-rules

      # misc
      betaflight-configurator
    ];

    programs = {
      # hyprland
      hyprland.enable = true;
      kitty.enable = true;
      obs-studio.enable = false;
      waybar.enable = true;

      # browsers
      chromium.enable = true;
      firefox.enable = true;

      # utils
      davinci.enable = false;
    };

    sgiath = {
      enable = true;
      audio.enable = true;
      email_client.enable = true;
    };
  };
}

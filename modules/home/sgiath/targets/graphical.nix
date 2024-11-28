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
      vlc
      okular
      plex-media-player

      syncthing-tray

      # comm
      webcord
      telegram-desktop
      signal-desktop
      cinny-desktop
      simplex-chat-desktop

      # bitcoin
      # bisq-desktop
      trezor-suite
      trezor-udev-rules

      # misc
      betaflight-configurator
    ];

    wayland.windowManager.hyprland.settings.exec-once = [
      # tools
      "${pkgs.obsidian}/bin/obsidian"

      # comms
      "${pkgs.webcord}/bin/webcord"
      "${pkgs.telegram-desktop}/bin/telegram-desktop"
      "${pkgs.signal-desktop}/bin/signal-desktop"
      "${pkgs.cinny-desktop}/bin/cinny"
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

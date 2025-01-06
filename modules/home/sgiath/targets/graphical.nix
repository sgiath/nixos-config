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
      nemo-with-extensions
      nemo-fileroller

      # utils
      vscodium-fhs
      obsidian
      gimp
      vlc
      okular
      plex-media-player
      texliveMedium
      libwacom

      # comm
      webcord
      telegram-desktop
      signal-desktop
      cinny-desktop
      fractal
      simplex-chat-desktop

      # bitcoin
      # bisq-desktop
      trezor-suite
      trezor-udev-rules

      # misc
      betaflight-configurator
    ];

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        # tools
        "${pkgs.kitty}/bin/kitty"
        "${pkgs.obsidian}/bin/obsidian"

        # comms
        "${pkgs.webcord}/bin/webcord"
        "${pkgs.telegram-desktop}/bin/telegram-desktop"
        "${pkgs.signal-desktop}/bin/signal-desktop"
        "${pkgs.cinny-desktop}/bin/cinny"
      ];
      bind = [
        "$mod, Return, exec, ${pkgs.kitty}/bin/kitty"
        "$mod, slash, exec, ${pkgs.wofi}/bin/wofi --show drun"
      ];
    };

    services = {
      udiskie.enable = true;
    };

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
      pandoc.enable = true;
    };

    sgiath = {
      enable = true;
      audio.enable = true;
      email_client.enable = true;
    };
  };
}

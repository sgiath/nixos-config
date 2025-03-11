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
      obsidian
      gimp
      vlc
      kdePackages.okular
      texliveMedium
      libwacom
      varia

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
        "${pkgs.fractal}/bin/fractal"
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

      # utils
      pandoc.enable = true;
    };

    # VSCode
    programs.vscode = {
      enable = true;
      profiles.default.userSettings = {
        "editor.tabSize" = 2;
        "editor.minimap.enabled" = false;
      };
    };
    stylix.targets.vscode.profileNames = [ "default" ];

    # Firefox
    programs.firefox.enable = true;
    stylix.targets.firefox.profileNames = [ "default" ];

    sgiath = {
      enable = true;
      audio.enable = true;
      email_client.enable = true;
    };
  };
}

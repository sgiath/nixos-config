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
      webp-pixbuf-loader

      # utils
      obsidian
      gimp
      vlc
      kdePackages.okular
      texliveMedium
      libwacom
      varia
      betaflight-configurator
      appimage-run
      davinci-resolve-studio

      code-cursor
    ];

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        # tools
        # "${pkgs.kitty}/bin/kitty"
        "${pkgs.obsidian}/bin/obsidian"
      ];
      bind = [
        # "$mod, Return, exec, ${pkgs.kitty}/bin/kitty"
        "$mod, slash, exec, ${pkgs.wofi}/bin/wofi --show drun"
      ];
    };

    services = {
      udiskie.enable = true;
    };

    programs = {
      # hyprland
      hyprland.enable = true;
      waybar.enable = true;

      # terminals
      alacritty.enable = true;
      kitty.enable = false;
      wezterm.enable = true;
      ghostty.enable = true;

      # utils
      pandoc.enable = true;
      vscode.enable = true;
      obs-studio.enable = true;
    };

    sgiath = {
      enable = true;
      audio.enable = true;
      bitcoin.enable = false;
      comm.enable = true;
      email_client.enable = true;
      web_browsers.enable = true;
    };
  };
}

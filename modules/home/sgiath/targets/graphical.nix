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
      xterm

      obsidian
      # libreoffice
      vlc
      kdePackages.okular
      libwacom
      appimage-run
    ];

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        "${pkgs.kitty}/bin/kitty"
        "${pkgs.obsidian}/bin/obsidian"
      ];
      bind = [
        "$mod, Return, exec, ${pkgs.kitty}/bin/kitty"
        "$mod, slash, exec, ${pkgs.wofi}/bin/wofi --show drun"
      ];
      windowrulev2 = [
        "workspace 1, class:(alacritty)"
        "workspace 1, class:(kitty)"
        "workspace 1, class:(wezterm)"
        "workspace 1, class:(ghostty)"

        "workspace 5 silent, class:(obsidian)"
        "noinitialfocus, class:(obsidian)"

        "workspace 7 silent, class:(com.obsproject.Studio)"
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
      alacritty.enable = false;
      kitty.enable = true;
      wezterm.enable = false;
      ghostty.enable = false;

      # utils
      pandoc.enable = true;
      vscode.enable = true;
      obs-studio.enable = true;
    };

    sgiath = {
      enable = true;
      audio.enable = true;
      bitcoin.enable = true;
      comm.enable = true;
      email_client.enable = true;
      web_browsers.enable = true;
    };

    xdg.desktopEntries."vue" = {
      name = "Visual Unederstanding Environment";
      genericName = "VUE";
      exec = "${pkgs.vue}/bin/vue";
    };
  };
}

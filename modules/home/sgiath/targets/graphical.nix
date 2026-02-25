{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options.sgiath.targets.graphical = lib.mkEnableOption "graphical target";

  config = lib.mkIf (config.sgiath.targets.graphical) {
    home.packages = with pkgs; [
      xterm

      gimp
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
      ];
      windowrule = [
        "match:class alacritty, workspace 1"
        "match:class kitty, workspace 1"
        "match:class wezterm, workspace 1"
        "match:class ghostty, workspace 1"

        "match:class obsidian, workspace 5 silent, no_initial_focus on"

        "match:class com.obsproject.Studio, workspace 7 silent"
      ];
    };

    services = {
      udiskie.enable = true;
      whisper-dict = {
        enable = true;
        model = "large-v3-turbo";
      };
    };

    programs = {
      # hyprland
      hyprland.enable = true;
      waybar.enable = true;

      voxtype = {
        enable = true;
        package = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
        model.name = "large-v3-turbo";
        service.enable = true;
        settings = {
          hotkey = {
            enabled = true;
            key = "RIGHTALT";
          };
          whisper.language = "en";
          audio = {
            device = "default";
            sample_rate = 16000;
            max_duration_secs = 60;
          };
        };
      };

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
      editors.enable = true;
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

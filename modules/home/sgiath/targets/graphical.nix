{
  inputs,
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  voxtype = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
in
{
  options.sgiath.targets.graphical = lib.mkEnableOption "graphical target";

  config = lib.mkIf (config.sgiath.targets.graphical) {
    home.packages = with pkgs; [
      xterm

      # gimp
      # libreoffice
      vlc
      kdePackages.okular
      libwacom
      appimage-run

      # T3 code
      pkgs.${namespace}.t3code
    ];

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        "${lib.getExe pkgs.kitty}"
        "${lib.getExe pkgs.obsidian}"
      ];
      bind = [
        "$mod, Return, exec, ${lib.getExe pkgs.kitty}"
        ", Alt_R, exec, ${lib.getExe voxtype} record start"
      ];
      bindr = [
        ", Alt_R, exec, ${lib.getExe voxtype} record stop"
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
      # whisper-dict = {
      #   enable = false;
      #   model = "large-v3-turbo";
      #   triggerKey = "rightctrl";
      #   minConfidence = 0.6;
      #   minRecordingMs = 250;
      # };
    };

    programs = {
      # hyprland
      hyprland.enable = true;
      noctalia-shell.enable = true;
      waybar.enable = false;

      # terminals
      alacritty.enable = false;
      kitty.enable = true;
      wezterm.enable = false;
      ghostty.enable = false;

      # utils
      pandoc.enable = true;
      vscode.enable = false;
      obs-studio.enable = true;

      obsidian = {
        enable = true;
        cli.enable = true;
      };

      voxtype = {
        enable = true;
        package = voxtype;
        model.name = "large-v3-turbo";
        service.enable = true;
        settings = {
          hotkey.enabled = false;
          whisper.language = "en";
        };
      };
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
      exec = "${lib.getExe pkgs.vue}";
    };
  };
}

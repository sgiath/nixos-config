{
  config,
  lib,
  pkgs,
  ...
}:
let
  terminalCommand = lib.getExe pkgs.kitty;
in
{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    home.packages = with pkgs; [
      xterm
      vlc
      kdePackages.okular
      libwacom
      appimage-run
    ];

    # Launch once per graphical session, never during Home Manager activation.
    systemd.user.timers.kitty = {
      Unit = {
        Description = "Launch Kitty at login";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        RefuseManualStart = true;
      };
      Timer = {
        OnActiveSec = "1s";
        AccuracySec = "1s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services.kitty = {
      Unit = {
        Description = "Kitty terminal";
        X-SwitchMethod = "keep-old";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        # Distinct app id so only this instance is pinned to workspace 1.
        ExecStart = "${terminalCommand} --class kitty-login";
        Slice = "app.slice";
      };
    };

    wayland.windowManager.hyprland.settings = {
      bind = [
        {
          _args = [
            "SUPER + Return"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON terminalCommand})")
          ];
        }
      ];
      window_rule = [
        {
          match.class = "kitty-login";
          workspace = "1";
        }
      ];
    };

    services = {
      udiskie.enable = true;
    };

    programs = {
      noctalia.enable = true;
      quickshell.enable = true;

      # terminals
      alacritty.enable = true;
      kitty = {
        enable = true;
        settings.auto_reload_config = -1;
      };
      wezterm.enable = true;
      ghostty.enable = true;

      # utils
      voxtype.enable = true;
      pandoc.enable = true;
      vscode.enable = false;
      obs-studio = {
        enable = true;
        plugins = with pkgs.obs-studio-plugins; [
          obs-backgroundremoval
        ];
      };

      obsidian = {
        enable = true;
        cli.enable = true;
      };
    };

    sgiath.programs = {
      audio.enable = true;
      bitcoin.enable = true;
      chat.enable = true;
      editors.enable = true;
      email.enable = true;
      browsers.enable = true;
    };

    xdg.desktopEntries."vue" = {
      name = "Visual Unederstanding Environment";
      genericName = "VUE";
      exec = "${lib.getExe pkgs.vue}";
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  aspellEnv = pkgs.aspellWithDicts (dicts: [ dicts.en ]);
  passBin = lib.getExe config.programs.password-store.package;
in
{
  config = lib.mkIf config.sgiath.programs.email.enable {
    home = {
      packages = with pkgs; [
        aspellEnv
        claws-mail
        w3m

        protonmail-bridge-gui
        protonmail-desktop

        proton-vpn
        proton-pass
        proton-pass-cli
        proton-authenticator
      ];

      file = {
        ".aspell.conf".text = ''
          dict-dir ${aspellEnv}/lib/aspell
          data-dir ${aspellEnv}/lib/aspell
        '';

        ".signature".text = ''
          Filip Vavera
          https://sgiath.dev

          GPG fingerprint:
          B166 3624 D093 688E D5C3 296B 70F9 C7DE 34CB 3BC8

          Why is HTML email a security nightmare? See https://useplaintext.email/
        '';
      };
    };

    accounts.email.accounts.proton = {
      primary = true;
      address = "FilipVavera@sgiath.dev";
      realName = "Filip Vavera";
      userName = "FilipVavera@sgiath.dev";
      aliases = [
        "FilipVavera@pm.me"
        "sgiath@sgiath.dev"
      ];
      # pass insert mail/proton-bridge
      passwordCommand = [
        passBin
        "show"
        "mail/proton-bridge"
      ];
      imap = {
        host = "127.0.0.1";
        port = 1143;
        tls.enable = true;
        tls.useStartTls = true;
      };
      smtp = {
        host = "127.0.0.1";
        port = 1025;
        tls.enable = true;
        tls.useStartTls = true;
      };
      folders = {
        inbox = "INBOX";
        sent = "Sent";
        drafts = "Drafts";
        trash = "Trash";
      };
      gpg = {
        key = "0x70F9C7DE34CB3BC8";
        signByDefault = true;
        encryptByDefault = true;
      };
      aerc = {
        enable = true;
        extraAccounts = {
          signature-file = "${config.home.homeDirectory}/.signature";
          check-mail = "5m";
          cache-headers = true;
          pgp-self-encrypt = true;
          pgp-attach-key = true;
        };
      };
    };

    programs.aerc = {
      enable = true;
      extraConfig = {
        general = {
          unsafe-accounts-conf = true;
          pgp-provider = "gpg";
        };
        ui = {
          dirlist-tree = true;
          sort = "-r date";
        };
        compose = {
          editor = lib.getExe pkgs.neovim;
          empty-subject-warning = true;
        };
        filters = {
          "text/plain" = "colorize";
          "text/html" = "${lib.getExe pkgs.w3m} -T text/html -dump";
          "text/calendar" = "calendar";
          "message/delivery-status" = "colorize";
          "message/rfc822" = "colorize";
          "application/pgp-keys" = "gpg --import";
        };
      };
    };

    xdg = {
      configFile."autostart/ProtonMailBridge.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Proton Mail Bridge
        Exec=${lib.getExe pkgs.protonmail-bridge-gui} --no-window
        Icon=protonmail-bridge-gui
        Terminal=false
        X-GNOME-Autostart-enabled=true
      '';

      desktopEntries.aerc = {
        name = "aerc";
        genericName = "Mail Client";
        comment = "Terminal mail via Proton Mail Bridge";
        exec = "${lib.getExe pkgs.kitty} --class aerc -e ${lib.getExe pkgs.aerc}";
        icon = "utilities-terminal";
        terminal = false;
        categories = [
          "Network"
          "Email"
        ];
      };
    };

    # Launch once per graphical session, never during Home Manager activation.
    systemd.user.timers.protonmail-desktop = {
      Unit = {
        Description = "Launch Proton Mail at login";
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

    systemd.user.services.protonmail-desktop = {
      Unit = {
        Description = "Proton Mail";
        X-SwitchMethod = "keep-old";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe pkgs.protonmail-desktop;
        Slice = "app.slice";
      };
    };

    wayland.windowManager.hyprland.settings = {
      window_rule = [
        {
          match.class = "claws-mail";
          workspace = "9 silent";
          no_initial_focus = true;
        }
        {
          match.class = "aerc";
          workspace = "9 silent";
        }
        {
          match.title = "Proton Mail";
          workspace = "9 silent";
          no_initial_focus = true;
        }
      ];
    };

    services.protonmail-bridge.enable = false;
  };
}

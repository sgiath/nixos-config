{ lib, ... }:
{
  imports = [
    ./role.nix
    ./chromium.nix
    ./clipboard.nix
    ./hyprland.nix
    ./noctalia.nix
    ./quickshell.nix
    ./shell.nix
    ./stylix.nix
    ./voxtype.nix
    ./yazi.nix
  ];

  options.sgiath = {
    roles.desktop.enable = lib.mkEnableOption "desktop role";

    desktop = {
      shell = lib.mkOption {
        type = lib.types.enum [
          "noctalia"
          "sgiath"
        ];
        default = "sgiath";
        description = ''
          Desktop shell started with the graphical session. `desktop-shell`
          switches between them at runtime; this only picks the login default.
        '';
      };

      wallpaper = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Image or video the `sgiath` shell plays on every screen's background
          layer. Videos loop muted; anything else is shown as a still image.
        '';
      };

      quickshell = {
        live = lib.mkEnableOption ''
          running the `sgiath` Quickshell config straight from the repository
          checkout (~/nixos) so edits hot-reload without a rebuild, plus QML
          tooling (qmlls, qmlformat) for editing it
        '';

        ignoredOutputs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "DP-2" ];
          description = ''
            Output names the `sgiath` shell leaves untouched: no wallpaper,
            no rail, no panels. For screens a single fullscreen window owns.
          '';
        };

        mainOutput = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "DP-1";
          description = ''
            Output that hosts the `sgiath` shell's single-instance surfaces:
            notifications, usage panel, crash drawer. Falls back to the widest
            non-ignored screen when unset or unplugged.
          '';
        };

        pinned = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "firefox"
            "dev.zed.Zed"
          ];
          description = ''
            Desktop entry ids the launcher keeps on top as large cells,
            launched with a single digit. The catalog is one search away.
          '';
        };
      };
    };
  };
}

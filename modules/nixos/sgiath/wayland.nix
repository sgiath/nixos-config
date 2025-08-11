{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options.sgiath.wayland = {
    enable = lib.mkEnableOption "wayland";
  };

  config = lib.mkIf config.sgiath.wayland.enable {
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1"; # hint electron apps to use wayland
      MOZ_ENABLE_WAYLAND = "1"; # ensure enable wayland for Firefox
      WLR_RENDERER_ALLOW_SOFTWARE = "1"; # enable software rendering for wlroots
      WLR_NO_HARDWARE_CURSORS = "1"; # disable hardware cursors for wlroots
      NIXOS_XDG_OPEN_USE_PORTAL = "1"; # needed to open apps after web login
    };
    environment.etc."issue".text = ''
      The Times 03/Jan/2009 Chancellor on brink of second bailout for banks
    '';

    services = {
      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --cmd Hyprland --issue";
            user = "greeter";
          };
        };
      };
      libinput = {
        enable = true;
        touchpad = {
          naturalScrolling = true;
        };
      };
      hypridle.enable = true;
    };

    security.pam.services.greetd = {
      allowNullPassword = true;
      startSession = true;
      enableGnomeKeyring = true;
      gnupg = {
        enable = true;
        noAutostart = true;
      };
    };

    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      # Without this errors will spam on screen
      StandardError = "journal";
      # Without these bootlogs will spam on screen
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };

    programs = {
      hyprland = {
        enable = true;
        # set the flake package
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        # make sure to also set the portal package, so that they are in sync
        portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      };

      hyprlock.enable = true;
    };
  };
}

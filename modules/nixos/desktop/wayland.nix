{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  hyprlandPkgs = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    # The upstream compositor uses its own nixpkgs; newer Mesa can require a newer glibc.
    hardware.graphics = {
      package = hyprlandPkgs.mesa;
      package32 = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 hyprlandPkgs.pkgsi686Linux.mesa;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1"; # hint electron apps to use wayland
      MOZ_ENABLE_WAYLAND = "1"; # ensure enable wayland for Firefox
      WLR_RENDERER_ALLOW_SOFTWARE = "1"; # enable software rendering for wlroots
      WLR_NO_HARDWARE_CURSORS = "1"; # disable hardware cursors for wlroots
    };
    environment.etc."issue".text = ''
      The Times 03/Jan/2009 Chancellor on brink of second bailout for banks
    '';

    services = {
      gnome.at-spi2-core.enable = true;

      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${lib.getExe pkgs.tuigreet} --time --asterisks --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --xsessions '' --cmd start-hyprland --issue";
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
    };

    security.pam.services.greetd = {
      startSession = true;
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

    systemd.user.services.xdg-desktop-portal-hyprland.serviceConfig.UnsetEnvironment = [
      "QT_QPA_PLATFORMTHEME"
      "QT_STYLE_OVERRIDE"
    ];

    programs.hyprland = {
      enable = true;
      # FIXME: Hyprland v0.56.x wraps bin/Hyprland in a shell script, and the nixpkgs
      # cap_sys_nice security wrapper rejects non-ELF targets. Upstream switched to
      # makeBinaryWrapper in 6cc0822e24 after v0.56.2; drop this override once the
      # pinned release includes that commit.
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland.override {
        makeWrapper = hyprlandPkgs.makeBinaryWrapper;
      };
    };
  };
}

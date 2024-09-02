{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.wayland = {
    enable = lib.mkEnableOption "wayland";
  };

  config = lib.mkIf config.sgiath.wayland.enable {
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.etc."issue".text = ''
      The Times 03/Jan/2009 Chancellor on brink of second bailout for banks
    '';

    # services.desktopManager.cosmic.enable = true;
    # services.displayManager.cosmic-greeter.enable = true;

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --asterisks --remember --cmd Hyprland --issue";
          user = "greeter";
        };
      };
    };

    security.pam.services.greetd = {
      allowNullPassword = true;
      startSession = true;
      enableGnomeKeyring = false;
      gnupg = {
        enable = true;
        noAutostart = true;
      };
    };

    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal"; # Without this errors will spam on screen
      # Without these bootlogs will spam on screen
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };

    nix.settings = {
      substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    };
  };
}

{ pkgs, userSettings, ... }:

{
  services = {
    xserver = {
      enable = true;
      excludePackages = [ pkgs.xterm ];

      # managed by home-manager
      desktopManager.session = [
        {
          name = "xmonad";
          start = ''
            ${pkgs.runtimeShell} $HOME/.xsession &
            waitPID=$!
          '';
        }
      ];

      displayManager = {
        lightdm.enable = true;

        autoLogin = {
          enable = true;
          user = userSettings.username;
        };

        sessionCommands = ''
          xset s off
          xset -dpms
          xset s noblank
        '';
      };

      # Configure keymap in X11
      xkb.layout = "us";

      # Enable touchpad support
      libinput = {
        enable = true;
        touchpad.naturalScrolling = true;
      };
    };

    dbus = {
      enable = true;
      packages = [ pkgs.dconf ];
    };
  };

  # OpenGL
  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
  };
}

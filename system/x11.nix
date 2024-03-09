{ config, pkgs, userSettings, ... }:

{
  services = {
    xserver = {
      enable = true;
      excludePackages = [ pkgs.xterm ];

      resolutions = [
        { x = 2560; y = 1440; }
      ];

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
      xkb = {
        layout = "us";
        options = "caps:escape";
      };

      # Enable touchpad support
      libinput.enable = true;
    };

    dbus = {
      enable = true;
      packages = [ pkgs.dconf ];
    };
  };

  # OpenGL
  hardware.opengl.enable = true;
}

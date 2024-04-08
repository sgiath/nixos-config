{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

{
  options.sgiath.x11 = {
    enable = lib.mkEnableOption "X11";
  };

  config = lib.mkIf config.sgiath.x11.enable {
    boot.kernelParams =
      if config.networking.hostName == "ceres" then
        [
          "video=DP-1:5120x1440@120"
          "video=DP-3:3440x1440@120"
          "video=DP-2:2560x1440@120"
        ]
      else
        lib.mkDefault [ ];

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

          setupCommands =
            if config.networking.hostName == "ceres" then
              ''
                ${pkgs.xorg.xrandr}/bin/xrandr \
                  --output DisplayPort-0 --mode 5120x1440 --refresh 120 --pos 0x2560 --primary \
                  --output DisplayPort-2 --mode 3440x1440 --refresh 120 --pos 0x1120 \
                  --output DisplayPort-1 --mode 2560x1440 --refresh 120 --pos 3440x0 --rotate left
              ''
            else
              "";

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
  };
}

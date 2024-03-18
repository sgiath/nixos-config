{ pkgs, ... }:

{
  boot.kernelParams = [
    "video=DP-1:5120x1440@120"
    "video=DP-3:3440x1440@120"
    "video=DP-2:2560x1440@120"
  ];

  services.xserver.displayManager.setupCommands = ''
    ${pkgs.xorg.xrandr}/bin/xrandr \
      --output DisplayPort-0 --mode 5120x1440 --refresh 120 --pos 0x2560 --primary \
      --output DisplayPort-2 --mode 3440x1440 --refresh 120 --pos 0x1120 \
      --output DisplayPort-1 --mode 2560x1440 --refresh 120 --pos 3440x0 --rotate left
  '';
}

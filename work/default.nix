{ pkgs, ... }:

{
  imports = [ ./aws.nix ];

  home.packages = with pkgs; [
    slack
    google-chrome
    insomnia
  ];

  # for wayland screensharing
  xdg.configFile."chrome-flags.conf".text = ''
    --ozone-platform-hint=auto
  '';
}

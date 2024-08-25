{ pkgs, ... }:

{
  imports = [ ./aws.nix ];

  home.packages = with pkgs; [
    slack
    google-chrome
    insomnia
  ];
}

{ inputs, ... }:
final: prev:
let
  pkgs-hyperland = inputs.hyprland.packages.${prev.system};
in
{
  hyprland = pkgs-hyperland.hyprland;
  xdg-desktop-portal-hyprland = pkgs-hyperland.xdg-desktop-portal-hyprland;

  conduwuit = inputs.conduwuit.packages.${prev.system}.all-features;
}

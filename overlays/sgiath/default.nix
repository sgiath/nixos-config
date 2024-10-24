{ inputs, ... }:
final: prev:
let
  pkgs-hyperland = inputs.hyprland.packages.${prev.system};
in
{
  # master version of packages
  master = inputs.nixpkgs-master.legacyPackages.${prev.system};

  # Hyprland main repo overrides
  hyprland = pkgs-hyperland.hyprland;
  xdg-desktop-portal-hyprland = pkgs-hyperland.xdg-desktop-portal-hyprland;

  # conduwuit is now broken in the main repo, so using the nixpkgs version
  # conduwuit = inputs.conduwuit.packages.${prev.system}.all-features;
}

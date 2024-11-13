{ inputs, ... }:
final: prev:
let
  pkgs-hyperland = inputs.hyprland.packages.${prev.system};
  pkgs-master = import inputs.nixpkgs-master {
    system = prev.system;
    config.allowUnfree = true;
  };
  pkgs-stable = import inputs.nixpkgs-stable {
    system = prev.system;
    config.allowUnfree = true;
  };
in
{
  # get Factorio updates as soon as possible
  factorio = pkgs-master.factorio-space-age-experimental;

  # Hyprland Nix native versions
  hyprland = pkgs-hyperland.hyprland;
  xdg-desktop-portal-hyprland = pkgs-hyperland.xdg-desktop-portal-hyprland;

  # conduwuit Nix native version
  conduwuit = inputs.conduwuit.packages.${prev.system}.all-features;

  # fix protonmail
  protonmail-bridge-gui = inputs.nixpkgs-proton.legacyPackages.${prev.system}.protonmail-bridge-gui;
}

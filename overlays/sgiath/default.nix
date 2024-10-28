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

  # Hyprland main repo overrides
  hyprland = pkgs-hyperland.hyprland;
  xdg-desktop-portal-hyprland = pkgs-hyperland.xdg-desktop-portal-hyprland;

  # conduwuit is now broken in the main repo, so using the nixpkgs version
  conduwuit = inputs.conduwuit.packages.${prev.system}.all-features;
}

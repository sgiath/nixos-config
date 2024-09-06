{ inputs, pkgs, ... }:
let
  pkgs-hyperland = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  additions = final: _prev: import ../pkgs final.pkgs;

  modifications = final: prev: {
    hyprland = pkgs-hyperland.hyprland;
    xdg-desktop-portal-hyprland = pkgs-hyperland.xdg-desktop-portal-hyprland;
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  master-packages = final: _prev: {
    master = import inputs.nixpkgs-master {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}

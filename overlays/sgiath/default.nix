{ inputs, ... }:
final: prev:
let
  pkgs-fix = import inputs.nixpkgs-fix {
    system = prev.system;
    config = {
      rocmSupport = false;
      allowUnfree = true;
    };
  };
  pkgs-master = import inputs.nixpkgs-master {
    system = prev.system;
    config = {
      rocmSupport = false;
      allowUnfree = true;
    };
  };
  pkgs-stable = import inputs.nixpkgs-stable {
    system = prev.system;
    config = {
      rocmSupport = false;
      allowUnfree = true;
    };
  };
in
{
  # conduwuit Nix native version
  conduwuit = inputs.conduwuit.packages.${prev.system}.all-features;

  # get Factorio updates as soon as possible
  factorio = pkgs-master.factorio-space-age-experimental;

  rocmPackages = pkgs-fix.rocmPackages;
}

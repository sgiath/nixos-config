{ inputs, pkgs, ... }:
final: prev:
let
  pkgs-master = import inputs.nixpkgs-master {
    system = prev.system;
    config = {
      rocmSupport = true;
      allowUnfree = true;
    };
  };
  pkgs-stable = import inputs.nixpkgs-stable {
    system = prev.system;
    config = {
      rocmSupport = true;
      allowUnfree = true;
    };
  };
in
{
  # conduwuit Nix native version
  conduwuit = inputs.conduwuit.packages.${prev.system}.all-features;

  # get Factorio updates as soon as possible
  factorio = pkgs-master.factorio-space-age-experimental;

  python3 = pkgs.python3.override {
    packageOverrides = self: super: {
      torch = super.torch.overrideAttrs (old: {
        meta = old.meta // {
          broken = false;
        };
      });
    };
  };
}

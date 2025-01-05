{ inputs, ... }:
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

  comfyui = inputs.nix-ai-stuff.packages.${prev.system}.comfyui;

  # FIXME: currently broken on unstable
  rocmPackages = pkgs-stable.rocmPackages;
}

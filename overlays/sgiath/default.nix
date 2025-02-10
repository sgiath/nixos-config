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
  # get Factorio updates as soon as possible
  factorio = pkgs-master.factorio-space-age-experimental;

  # broken rocm on unstable
  # https://github.com/NixOS/nixpkgs/pull/377629
  # ollama-rocm = pkgs-master.ollama-rocm;
  # rocmPackages = pkgs-master.rocmPackages;
}

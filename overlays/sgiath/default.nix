{ inputs, ... }:
final: prev:
let
  # pkgs-master = import inputs.nixpkgs-master {
  #   system = prev.stdenv.hostPlatform.system;
  # };

  # pkgs-stable = import inputs.nixpkgs-stable {
  #   system = prev.stdenv.hostPlatform.system;
  # };

  pkgs-ksa = import inputs.nixpkgs-ksa {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  ksa = pkgs-ksa.ksa;
}

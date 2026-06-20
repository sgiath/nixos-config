{ inputs, ... }:
final: prev:
let
  pkgs-ksa = import inputs.nixpkgs-ksa {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  ksa = pkgs-ksa.ksa;
}

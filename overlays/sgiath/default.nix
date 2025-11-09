{ inputs, ... }:
final: prev:
let
  pkgs-master = import inputs.nixpkgs-master {
    system = prev.stdenv.hostPlatform.system;
    config = {
      cudaSupport = false;
      rocmSupport = false;
      allowUnfree = true;
    };
  };
  pkgs-stable = import inputs.nixpkgs-stable {
    system = prev.stdenv.hostPlatform.system;
    config = {
      cudaSupport = false;
      rocmSupport = false;
      allowUnfree = true;
    };
  };
in
{
  # conduit build from official repo flake
  matrix-conduit = inputs.conduit.packages.${prev.stdenv.hostPlatform.system}.default;

  # zen browser has custom repo until nixpkgs is updated
  zen-browser = inputs.zen-browser.packages.${prev.stdenv.hostPlatform.system}.default;

  # NIX Gaming
  star-citizen = inputs.nix-gaming.packages.${prev.stdenv.hostPlatform.system}.star-citizen;

  # Bitcoin clients
  bisq = inputs.btc-clients.packages.${prev.stdenv.hostPlatform.system}.bisq;
  sparrow = inputs.btc-clients.packages.${prev.stdenv.hostPlatform.system}.sparrow;
}

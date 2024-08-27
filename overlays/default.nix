{
  config,
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.overlays = [
    (final: prev: {
      python3Packages.sbapp = prev.callPackage ./sbapp.nix { inherit pkgs lib; };
    })
  ];
}

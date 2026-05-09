{ inputs, ... }:
final: prev:
let
  pkgs-master = import inputs.nixpkgs-master {
    system = prev.stdenv.hostPlatform.system;
    config = {
      cudaSupport = false;
      rocmSupport = true;
      allowUnfree = true;
    };
  };

  pkgs-stable = import inputs.nixpkgs-stable {
    system = prev.stdenv.hostPlatform.system;
    config = {
      cudaSupport = false;
      rocmSupport = true;
      allowUnfree = true;
    };
  };

  pkgs-ksa = import inputs.nixpkgs-ksa {
    system = prev.stdenv.hostPlatform.system;
    config = {
      cudaSupport = false;
      rocmSupport = true;
      allowUnfree = true;
    };
  };
in
{
  ksa = pkgs-ksa.ksa;
  codex = pkgs-master.codex;
  zed-editor = pkgs-master.zed-editor;

  # Skipping tests while upstream sorts it out, revert once
  # Hydra consistently builds openldap green.
  # https://github.com/NixOS/nixpkgs/issues/513245
  # https://github.com/NixOS/nixpkgs/issues/514113
  openldap = prev.openldap.overrideAttrs (_: {
    doCheck = false;
  });
}

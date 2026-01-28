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
  # mdformat = pkgs-master.mdformat;
  # searxng = pkgs-master.searxng;
}

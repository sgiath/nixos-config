{ inputs, ... }:
final: prev:
let
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
      rocmSupport = true;
      allowUnfree = true;
    };
  };
in
{
  # conduit build from official repo flake
  # matrix-conduit = inputs.conduit.packages.${prev.system}.default;

  # zen browser has custom repo until nixpkgs is updated
  zen-browser = inputs.zen-browser.packages.${prev.system}.default;

  # get Factorio updates as soon as possible
  factorio = pkgs-master.factorio-space-age-experimental;

  # get open-webui updates sooner
  open-webui = pkgs-master.open-webui;

  # broken on unstable for me
  audiobookshelf = pkgs-stable.audiobookshelf;
}

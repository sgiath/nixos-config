{ inputs, ... }:
final: prev:
let
  pkgs-drupol = import inputs.nixpkgs-drupol {
    system = prev.system;
    config = {
      rocmSupport = false;
      allowUnfree = true;
    };
  };
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
  # conduwuit build from official repo flake
  # conduwuit = inputs.conduwuit.packages.${prev.system}.all-features;

  # zen browser has custom repo until nixpkgs is updated
  zen-browser = inputs.zen-browser.packages.${prev.system}.default;

  # get Factorio updates as soon as possible
  factorio = pkgs-master.factorio-space-age-experimental;

  # get open-webui updates sooner
  # open-webui = pkgs-master.open-webui;
  open-webui = pkgs-drupol.open-webui;

  # broken on unstable for me
  audiobookshelf = pkgs-stable.audiobookshelf;
}

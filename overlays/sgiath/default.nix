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
  matrix-conduit = inputs.conduit.packages.${prev.system}.default;

  # zen browser has custom repo until nixpkgs is updated
  zen-browser = inputs.zen-browser.packages.${prev.system}.default;

  # NIX Gaming
  star-citizen = inputs.nix-gaming.packages.${prev.system}.star-citizen;

  # get open-webui from a configuration with ROCm support off
  open-webui = pkgs-master.open-webui;

  # get n8n updates sooner
  n8n = pkgs-master.n8n;
  awscli2 = pkgs-master.awscli2;

  # Bitcoin clients
  bisq = inputs.btc-clients.packages.${prev.system}.bisq;
  sparrow = inputs.btc-clients.packages.${prev.system}.sparrow;
}

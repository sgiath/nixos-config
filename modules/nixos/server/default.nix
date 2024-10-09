{ lib, ... }:
{
  imports = [
    ./5e.nix
    ./audiobookshelf.nix
    ./foundry.nix
    ./home-assistant.nix
    ./matrix.nix
    ./nginx.nix
    ./osm.nix
    ./pi-hole.nix
    ./search.nix
    ./sgiath.nix
    ./wordpress.nix
  ];

  options.sgiath.server = {
    enable = lib.mkEnableOption "sgiath server";
  };
}

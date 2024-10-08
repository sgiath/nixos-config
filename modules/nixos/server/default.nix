{ lib, ... }:
{
  imports = [
    ./5e.nix
    ./audiobookshelf.nix
    ./foundry.nix
    ./home-assistant.nix
    ./nginx.nix
    ./pi-hole.nix
    ./search.nix
    ./wordpress.nix
  ];

  options.sgiath.server = {
    enable = lib.mkEnableOption "sgiath server";
  };
}

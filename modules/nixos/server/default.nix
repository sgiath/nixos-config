{ lib, ... }:
{
  imports = [
    ./5e.nix
    ./audiobookshelf.nix
    ./cryptpad.nix
    ./factorio.nix
    ./foundry.nix
    ./home-assistant.nix
    ./jitsi.nix
    ./mailserver.nix
    ./matrix.nix
    ./monitoring.nix
    ./n8n.nix
    ./nas.nix
    ./nginx.nix
    ./osm.nix
    ./pi-hole.nix
    ./search.nix
    ./sgiath.nix
    ./sinai.nix
    ./wordpress.nix
    ./xmpp.nix
  ];

  options.sgiath.server = {
    enable = lib.mkEnableOption "sgiath server";
  };
}

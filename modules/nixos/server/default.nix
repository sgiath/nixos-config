{ lib, ... }:
{
  imports = [
    ./5e.nix
    ./audiobookshelf.nix
    ./cryptpad.nix
    ./factorio.nix
    ./focalboard.nix
    ./foundry.nix
    ./home-assistant.nix
    ./jitsi.nix
    ./kanboard.nix
    ./matrix.nix
    ./mattermost.nix
    ./minecraft.nix
    ./monitoring.nix
    ./n8n.nix
    ./nas.nix
    ./nginx.nix
    ./ntfy.nix
    ./open-webui.nix
    ./osm.nix
    ./photo.nix
    ./pi-hole.nix
    ./plex.nix
    ./search.nix
    ./sgiath.nix
    ./sinai.nix
    ./torrent.nix
    ./vault.nix
    ./wordpress.nix
    ./xmpp.nix
    ./zitadel.nix
  ];

  options.sgiath.server = {
    enable = lib.mkEnableOption "sgiath server";
  };
}

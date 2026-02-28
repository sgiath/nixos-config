{ lib, ... }:
{
  imports = [
    ./5e.nix
    ./audiobookshelf.nix
    ./factorio.nix
    ./foundry.nix
    ./jellyfin.nix
    ./matrix.nix
    ./minecraft.nix
    ./monitoring.nix
    ./nas.nix
    ./nginx.nix
    ./nostr.nix
    ./ntfy.nix
    ./openclaw.nix
    ./opencode.nix
    ./pi-hole.nix
    ./search.nix
    ./sgiath.nix
    ./sinai.nix
    ./torrent.nix
    ./xmpp.nix
  ];

  options.sgiath.server = {
    enable = lib.mkEnableOption "sgiath server";
  };
}

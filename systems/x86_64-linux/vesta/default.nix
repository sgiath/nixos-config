{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "vesta";
  networking.wireguard.enable = false;

  sgiath = {
    enable = true;
    docker.enable = true;
    server.enable = true;
  };

  services = {
    audiobookshelf.enable = true;
    matrix.enable = true;
    pi-hole.enable = true;
    searx.enable = true;
    transmission.enable = true;
    jellyfin.enable = true;
    nostr-rs-relay.enable = true;

    foundryvtt.enable = true;
    dnd5etools.enable = true;
    factorio.enable = false;

    open-webui.enable = false;
    mollysocket.enable = true;
    ntfy-sh.enable = true;
    yggdrasil.enable = true;
    monitoring.enable = false;

    # proxies
    nas-proxy.enable = true;
    sgiath-dev.proxy = true;
    sinai-camp.proxy = true;
    opencode-proxy.enable = false;
    openclaw-proxy.enable = true;
  };
}

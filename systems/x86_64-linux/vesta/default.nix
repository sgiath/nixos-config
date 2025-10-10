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
    n8n.enable = true;
  };

  services = {
    audiobookshelf.enable = true;
    matrix.enable = true;
    pi-hole.enable = true;
    searx.enable = true;
    transmission.enable = true;
    jellyfin.enable = true;
    vaultwarden.enable = false;
    mattermost.enable = true;

    foundryvtt.enable = true;
    dnd5etools.enable = true;

    open-webui.enable = false;
    home-assistant.enable = false;
    mollysocket.enable = true;
    ntfy-sh.enable = true;

    cryptpad.enable = false;
    factorio.enable = false;
    jitsi-meet.enable = false;
    focalboard.enable = false;
    zitadel.enable = false;
    photoprism.enable = false;
    monitoring.enable = false;

    # proxies
    nas-proxy.enable = true;
    osm.proxy = true;
    sgiath-dev.proxy = true;
    sinai-camp.proxy = true;
    wordpress.proxy = false;
  };
}

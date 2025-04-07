{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "vesta";

  sgiath = {
    enable = true;
    docker.enable = true;
    server.enable = true;
    n8n.enable = true;
  };

  services = {
    dnd5etools.enable = true;
    audiobookshelf.enable = true;
    cryptpad.enable = false;
    factorio.enable = false;
    foundryvtt.enable = true;
    home-assistant.enable = true;
    jitsi-meet.enable = false;
    matrix.enable = true;
    monitoring.enable = true;
    pi-hole.enable = true;
    searx.enable = true;
    mollysocket.enable = true;
    focalboard.enable = true;
    zitadel.enable = false;

    # AI
    open-webui.enable = true;

    # proxies
    nas-proxy.enable = true;
    osm.proxy = true;
    sgiath-dev.proxy = true;
    sinai-camp.proxy = true;
    wordpress.proxy = false;
  };
}

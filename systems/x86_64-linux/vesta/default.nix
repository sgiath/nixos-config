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
    monitoring.enable = false;
    pi-hole.enable = true;
    searx.enable = true;
    mollysocket.enable = true;

    # AI
    n8n.enable = true;
    open-webui.enable = true;

    # proxies
    nas-proxy.enable = true;
    sgiath-dev.proxy = true;
    sinai-camp.proxy = true;
    wordpress.proxy = false;
  };
}

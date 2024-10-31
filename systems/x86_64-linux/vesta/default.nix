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
    cryptpad.enable = true;
    foundryvtt.enable = true;
    home-assistant.enable = true;
    jitsi-meet.enable = true;
    matrix.enable = true;
    monitoring.enable = true;
    pi-hole.enable = true;
    searx.enable = true;

    # proxies
    nas-proxy.enable = true;
    sgiath-dev.proxy = true;
    sinai-camp.proxy = true;
    wordpress.proxy = false;
  };
}

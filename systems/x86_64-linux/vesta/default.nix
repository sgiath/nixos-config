{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "vesta";

  sgiath = {
    enable = true;
    server.enable = true;
  };

  services = {
    dnd5etools.enable = false;
    audiobookshelf.enable = true;
    pi-hole.enable = true;
    foundryvtt.enable = true;
    home-assistant.enable = true;
  };
}

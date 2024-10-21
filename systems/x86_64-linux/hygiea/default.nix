{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "hygiea";

  sgiath = {
    enable = true;
    boot = "legacy";
    server.enable = true;
  };
}

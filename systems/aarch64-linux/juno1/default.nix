{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "juno1";

  sgiath = {
    enable = true;
    hardware.dgx-spark.enable = true;
  };
}

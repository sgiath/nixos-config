{ lib, ... }:
{
  imports = [
    ./nas.nix
    ./sgiath-dev.nix
    ./sinai-camp.nix
    ./wkd.nix
  ];

  options.sgiath.sites = {
    sgiath-dev.enable = lib.mkEnableOption "sgiath.dev proxy";
    sinai-camp.enable = lib.mkEnableOption "sinai.camp proxy";
    nas.enable = lib.mkEnableOption "NAS proxy";
  };
}

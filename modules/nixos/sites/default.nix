{ lib, ... }:
{
  imports = [
    ./nas.nix
    ./sinai-camp.nix
  ];

  options.sgiath.sites = {
    sinai-camp.enable = lib.mkEnableOption "sinai.camp proxy";
    nas.enable = lib.mkEnableOption "NAS proxy";
  };
}

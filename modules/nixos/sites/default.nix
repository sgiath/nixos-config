{ lib, ... }:
{
  imports = [
    ./crazyeggdev.nix
    ./nas.nix
    ./sinai-camp.nix
  ];

  options.sgiath.sites = {
    crazyeggdev.enable = lib.mkEnableOption "CrazyEgg development proxy to ce-local-infra";
    sinai-camp.enable = lib.mkEnableOption "sinai.camp proxy";
    nas.enable = lib.mkEnableOption "NAS proxy";
  };
}

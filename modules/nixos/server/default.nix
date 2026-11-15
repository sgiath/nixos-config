{ lib, ... }:
{
  imports = [
    ./minecraft.nix
    ./nginx.nix
  ];

  options.sgiath.roles.server.enable = lib.mkEnableOption "home server role";
}

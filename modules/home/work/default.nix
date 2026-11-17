{ lib, ... }:
{
  imports = [
    ./aws.nix
    ./crazyegg.nix
    ./remote.nix
  ];

  options.sgiath.work = {
    crazyegg.enable = lib.mkEnableOption "CrazyEgg home manager";
    crazyegg.warp.enable = lib.mkEnableOption "Cloudflare WARP for CrazyEgg's Zero Trust network (the NixOS side runs the daemon and split DNS)";
    remote.enable = lib.mkEnableOption "Remote home manager";
  };
}

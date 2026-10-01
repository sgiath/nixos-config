{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cachePolicy = (import ../../../flake.nix).nixConfig;
in
{
  config = lib.mkIf config.sgiath.enable {
    nix = {
      package = pkgs.nixVersions.latest;
      settings = {
        nix-path = [ "nixpkgs=${inputs.nixpkgs}" ];
        auto-optimise-store = true;
        require-sigs = true;
        trusted-users = [
          "root"
          "sgiath"
        ];
        experimental-features = [
          "nix-command"
          "flakes"
          "pipe-operators"
        ];
        trusted-substituters = cachePolicy.extra-substituters;
        trusted-public-keys = cachePolicy.extra-trusted-public-keys;
      };
      channel.enable = false;
      optimise.automatic = true;
      gc = {
        automatic = false;
        dates = "08:00";
      };
    };
    systemd.services.nix-daemon.serviceConfig = {
      MemoryMax = "24G";
      MemoryHigh = "20G";
    };
    home-manager.backupFileExtension = "backup";
  };
}

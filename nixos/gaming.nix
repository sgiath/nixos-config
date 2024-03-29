{ config, lib, pkgs, ... }:

{
  options.sgiath.gaming = { enable = lib.mkEnableOption "gaming"; };

  config = lib.mkIf config.sgiath.gaming.enable {
    # gaming kernel
    boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

    # Steam
    programs.steam.enable = true;
    programs.gamemode.enable = true;

    # enable Cachix for gaming
    nix.settings = {
      substituters = [ "https://nix-gaming.cachix.org" ];
      trusted-public-keys = [
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      ];
    };
  };
}

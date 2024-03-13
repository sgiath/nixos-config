{ config, pkgs, pkgs-citizen, ...}:

{
  home = {
    packages = [
      pkgs.discord
      pkgs.lutris

      pkgs.winePackages.unstableFull
      pkgs.winePackages.fonts
      pkgs.winetricks

      # Star Citizen
      pkgs-citizen.star-citizen-helper
      pkgs-citizen.lug-helper
    ];
  };
}

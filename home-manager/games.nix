{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  pkgs-citizen = inputs.nix-citizen.packages.${pkgs.system};
in
{
  options.sgiath.games = {
    enable = lib.mkEnableOption "games";
  };

  config = lib.mkIf config.sgiath.games.enable {
    home = {
      packages = [
        # general tools
        pkgs.webcord
        pkgs.teamspeak_client
        pkgs.lutris
        pkgs.gamescope
        (pkgs.prismlauncher.override {
          jdks = with pkgs; [
            jdk21
            jdk8
          ];
        })

        pkgs.winetricks

        # Star Citizen
        (pkgs-citizen.star-citizen.override {
          tricks = [
            "arial"
            "vcrun2019"
            "win10"
            "sound=alsa"
          ];
        })
      ];
    };
  };
}

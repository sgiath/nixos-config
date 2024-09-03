{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
{
  options.sgiath.games = {
    enable = lib.mkEnableOption "games";
  };

  config = lib.mkIf config.sgiath.games.enable {
    home = {
      packages = [
        # general tools
        pkgs.webcord
        pkgs.lutris
        pkgs.protonup
        (pkgs.prismlauncher.override {
          jdks = with pkgs; [
            jdk21
            jdk8
          ];
        })

        pkgs.winetricks

        # Star Citizen
        # I need ALSA for audio to work correctly
        # (pkgs-citizen.star-citizen.override {
        #   tricks = [
        #     "arial"
        #     "vcrun2019"
        #     "win10"
        #     "sound=alsa"
        #   ];
        # })

        # Factorio
        (pkgs.factorio.override {
          username = "Sgiath";
          token = secrets.factorio_token;
        })
      ];

      sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
      };
    };
  };
}

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
        (pkgs.prismlauncher.override {
          jdks = with pkgs; [
            jdk21
            jdk8
          ];
        })

        pkgs.winetricks

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

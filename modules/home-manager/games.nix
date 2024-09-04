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
      packages = with pkgs; [
        (lutris.override {
          extraPkgs = pkgs: [ pkgs.gnome3.adwaita-icon-theme ];
        })

        # Minecraft
        (prismlauncher.override {
          jdks = [
            jdk21
            jdk8
          ];
        })

        # Factorio
        (factorio.override {
          username = "Sgiath";
          token = secrets.factorio_token;
        })
      ];
    };
  };
}

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
          extraLibraries = pkgs: [
            # libraries for Principia
            pkgs.llvmPackages.libcxx
            pkgs.llvmPackages.libunwind
          ];

          extraPkgs = pkgs: [
            # default icons
            pkgs.adwaita-icon-theme

            # MS fonts needed for KSP
            pkgs.corefonts
          ];
        })

        # KSP mods
        ckan

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

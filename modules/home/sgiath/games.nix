{
  config,
  lib,
  pkgs,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  options.sgiath.games = {
    enable = lib.mkEnableOption "games";
  };

  config = lib.mkIf config.sgiath.games.enable {
    home.packages = with pkgs; [
      protonplus

      # wine64
      winetricks
      wineWowPackages.waylandFull

      (lutris.override {
        extraLibraries = pkgs: [
          # libraries for KSP mod Principia
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
          zulu25
          zulu8
        ];
      })

      # Factorio
      (factorio-space-age-experimental.override {
        username = "Sgiath";
        token = secrets.factorio_token;
      })

      # star-citizen
    ];

    wayland.windowManager.hyprland.settings.windowrulev2 = [
      "workspace 6 silent, class:(.factorio-wrapped)"
      "workspace 6 silent, class:(battle.net.exe)"
      "workspace 6 silent, class:(lutris)"
    ];
  };
}

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

      # Minecraft
      (prismlauncher.override {
        jdks = [
          # GT: New Horizons
          zulu25
          # Vanilla
          zulu21
          # Nomifactory
          zulu8
        ];
      })

      # KSP mods
      ckan

      # Kitten Space Agency
      ksa

      # Factorio
      (factorio-space-age-experimental.override {
        username = "Sgiath";
        token = secrets.factorio_token;
      })

      # inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.star-citizen
    ];

    wayland.windowManager.hyprland.settings.windowrule = [
      "match:class .factorio-wrapped, workspace 6 silent"
      "match:class lutris, workspace 6 silent"
      "match:class steam_app_8500, float on"
    ];
  };
}

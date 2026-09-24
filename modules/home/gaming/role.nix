{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.roles.gaming.enable {
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

      factorio-space-age-experimental

      # inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.star-citizen
    ];

    wayland.windowManager.hyprland.settings.window_rule = [
      {
        match.class = ".factorio-wrapped";
        workspace = "6 silent";
      }
      {
        match.class = "lutris";
        workspace = "6 silent";
      }
      {
        match.class = "steam_app_8500";
        float = true;
      }
    ];
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.roles.gaming.enable {
    environment.systemPackages = with pkgs; [
      protonplus
      winetricks
    ];

    programs = {
      gamescope.enable = true;
      gamemode.enable = true;

      wine = {
        enable = true;
        binfmt = true;
        ntsync = true;
        package = pkgs.wineWow64Packages.waylandFull;
      };

      steam = {
        enable = true;
        package = pkgs.steam.override {
          extraPkgs =
            pkgs: with pkgs; [
              gamemode
              libpulseaudio
              libpng
              libgpg-error
              keyutils
            ];
        };
        remotePlay.openFirewall = true;
        protontricks.enable = true;
        gamescopeSession.enable = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
      };
    };

    sops.secrets.factorio-token = {
      key = "factorio_token";
      mode = "0400";
    };
    sops.templates.factorio-env = {
      content = ''
        NIX_FACTORIO_USERNAME=Sgiath
        NIX_FACTORIO_TOKEN=${config.sops.placeholder.factorio-token}
      '';
      mode = "0400";
      restartUnits = [ "nix-daemon.service" ];
    };
    # The upstream fetcher reads these from the daemon via impureEnvVars.
    systemd.services.nix-daemon.serviceConfig.EnvironmentFile = config.sops.templates.factorio-env.path;
  };
}

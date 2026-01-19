{ pkgs, ... }:
let
  # opencode = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
  opencode = pkgs.opencode;
in
{
  imports = [ ./hardware.nix ];

  networking.hostName = "ceres";

  sgiath = {
    enable = true;
    gpu = "amd";
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    xamond.enable = true;
    printing.enable = true;
    razer.enable = false;
    wayland.enable = true;
  };

  crazyegg.enable = true;

  services = {
    ollama.enable = false;
    flatpak.enable = true;
  };

  programs = {
    gamescope.enable = true;
    gamemode.enable = true;

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

  systemd.user.services.opencode-web = {
    enable = true;

    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    description = "OpenCode Web Interface";
    environment = {
      OPENCODE_SERVER_PASSWORD = "";
    };

    script = "${opencode}/bin/opencode web --host 0.0.0.0 --port 12345";

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}

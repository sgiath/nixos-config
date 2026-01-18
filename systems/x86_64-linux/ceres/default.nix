{ inputs, pkgs, ... }:
let
  opencode = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
    Unit = {
      Description = "OpenCode Web Interface";
      After = [ "network.target" ];
    };
    Service = {
      Environment = [
        "OPENCODE_SERVER_PASSWORD=\"\""
      ];
      ExecStart = "${opencode}/bin/opencode web --host 0.0.0.0 --port 12345";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}

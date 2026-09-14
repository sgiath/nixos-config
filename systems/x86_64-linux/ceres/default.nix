{ config, ... }:
{
  imports = [ ./hardware.nix ];

  networking.hostName = "ceres";

  sgiath = {
    enable = true;

    hardware.gpu = "amd";

    roles = {
      desktop.enable = true;
      gaming.enable = true;
    };
  };

  virtualisation.docker.enable = true;

  services = {
    ollama.enable = false;
    comfyui.enable = false;

    yggdrasil.settings.Peers = [
      "quic://192.168.1.2:56088"
      "quic://192.168.1.3:56088"
    ];
  };

  # Build-signing key for closures pushed to the servers; the public half is
  # secrets/ceres-cache.pub.
  sops.secrets = {
    nix-signing-key = {
      sopsFile = ../../../secrets/ceres-signing.yaml;
      key = "nix-signing-key";
      mode = "0400";
      restartUnits = [ "nix-daemon.service" ];
    };

    openclaw-token = {
      owner = "sgiath";
      mode = "0400";
    };
  };

  nix.settings.secret-key-files = [ config.sops.secrets.nix-signing-key.path ];
}

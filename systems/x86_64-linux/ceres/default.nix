{ config, lib, ... }:
let
  vesta = config.sgiath.nebula.peers.vesta;
in
{
  imports = [
    ./hardware.nix
    ./qwen-image.nix
  ];

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

  # herdr.sgiath.dev on Vesta drives this PC's herdr as a remote PC: it logs
  # in with its own key (secrets/vesta.yaml), installs its bridge runtime and
  # forwards the bridge's loopback port. Only from Vesta's overlay addresses,
  # and only forwarding to loopback.
  users.users.sgiath.openssh.authorizedKeys.keys = [
    ''from="${vesta.ip4},${vesta.ip6}",restrict,port-forwarding,permitopen="127.0.0.1:*" ${lib.fileContents ../../../secrets/herdr-web-ceres.pub}''
  ];

  nix.settings.secret-key-files = [ config.sops.secrets.nix-signing-key.path ];
}

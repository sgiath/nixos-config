{ config, ... }:
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

  # Ceres sits on Vesta's LAN, so reach it directly: router hairpin NAT to
  # the public lighthouse address has stranded the tunnel on stale conntrack
  # entries. The public endpoint from the shared module stays as fallback.
  services.nebula.networks.sgiath = {
    staticHostMap =
      let
        vesta = config.sgiath.nebula.peers.vesta;
      in
      {
        ${vesta.ip4} = [ "192.168.1.2:4242" ];
        ${vesta.ip6} = [ "192.168.1.2:4242" ];
      };
    settings.preferred_ranges = [ "192.168.1.0/24" ];
  };

  services = {
    ollama.enable = false;
  };

  # Build-signing key for closures pushed to the servers; the public half is
  # secrets/ceres-cache.pub.
  sops.secrets.nix-signing-key = {
    sopsFile = ../../../secrets/ceres-signing.yaml;
    key = "nix-signing-key";
    mode = "0400";
    restartUnits = [ "nix-daemon.service" ];
  };

  nix.settings.secret-key-files = [ config.sops.secrets.nix-signing-key.path ];
}

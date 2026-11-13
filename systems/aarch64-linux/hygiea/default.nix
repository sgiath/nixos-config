# Hygiea: Oracle Cloud Always Free A1 VM (Frankfurt) that keeps the overlay up
# while Vesta is down. It runs without the sgiath.enable baseline: Nebula as
# second lighthouse/relay, a backup Pi-hole, the append-only offsite backup
# target for Vesta and Gatus watching home from outside. It is an untrusted
# peer and its secrets live only in secrets/hygiea.yaml. INSTALL.md is the
# runbook.
{ ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
    ./backup.nix
    ./monitoring.nix
  ];

  networking.hostName = "hygiea";
  system.stateVersion = "26.11";

  sgiath.nebula = {
    enable = true;
    secretsFile = ../../../secrets/hygiea.yaml;
  };
  services.pi-hole.enable = true;

  sops = {
    defaultSopsFile = ../../../secrets/hygiea.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    gnupg.sshKeyPaths = [ ];
  };

  # Public host: only SSH, Nebula (UDP 4242, opened by the Nebula module) and
  # ICMP face the internet; everything else listens on the overlay. UDP 443
  # is redirected to Nebula (Hygiea's second endpoint in the peers table) for
  # networks that pass outbound UDP only to well-known ports.
  networking.firewall =
    let
      rule = "PREROUTING -p udp --dport 443 -j REDIRECT --to-ports 4242";
    in
    {
      enable = true;
      # Delete first: these run again on every firewall reload.
      extraCommands = ''
        iptables -t nat -D ${rule} 2>/dev/null || true
        ip6tables -t nat -D ${rule} 2>/dev/null || true
        iptables -t nat -A ${rule}
        ip6tables -t nat -A ${rule}
      '';
      extraStopCommands = ''
        iptables -t nat -D ${rule} 2>/dev/null || true
        ip6tables -t nat -D ${rule} 2>/dev/null || true
      '';
    };

  users.users.sgiath = import ../../../modules/nixos/common/account.nix // {
    extraGroups = [ "wheel" ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # `update` builds on the host itself (deployNative); one core, so one job.
  nix = {
    channel.enable = false;
    settings = {
      trusted-users = [
        "root"
        "sgiath"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = 1;
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  zramSwap.enable = true;
  services.journald.settings.Journal.SystemMaxUse = "500M";
}

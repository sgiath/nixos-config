{ config, lib, ... }:
{
  config = lib.mkIf config.programs.ssh.enable {
    programs.ssh = {
      enableDefaultConfig = false;

      matchBlocks = {
        # git
        "github.com" = {
          hostname = "github.com";
          user = "git";
        };
        "sr.ht" = {
          hostname = "git.sr.ht";
          user = "git";
        };

        # servers
        "vesta.sgiath.dev" = {
          hostname = "193.165.30.198";
          port = 2200;
        };

        # local network
        "turris.local" = {
          hostname = "192.168.1.1";
          user = "root";
        };
        "vesta.local".hostname = "192.168.1.3";
        "nas.local".hostname = "192.168.1.4";
        "ceres.local".hostname = "192.168.1.7";

        # CrazyEgg
        "bastion.crazyegg.com" = {
          hostname = "us-east-1.general-purpose.bastion.crazyegg.com";
          user = "filip";
          proxyCommand = "none";
          forwardAgent = true;
        };
        "i.*.crazyegg.com" = {
          user = "crazyegg";
          proxyCommand = "ssh bastion.crazyegg.com -W %h:%p";
        };

        # defaults
        "*" = {
          user = "sgiath";
          port = 22;
          compression = true;
          serverAliveInterval = 60;
          serverAliveCountMax = 30;

          extraOptions = {
            Protocol = "2";

            PasswordAuthentication = "yes";
            ChallengeResponseAuthentication = "yes";
            PubkeyAuthentication = "yes";
            PreferredAuthentications = "publickey";

            Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr";
            KexAlgorithms = "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
            HostKeyAlgorithms = "ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa";
            MACs = "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256";
          };
        };
      };
    };
  };
}

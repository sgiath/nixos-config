{ config, lib, ... }:
{
  config = lib.mkIf config.programs.ssh.enable {
    programs.ssh = {
      compression = true;
      serverAliveInterval = 60;
      serverAliveCountMax = 30;
      extraConfig = ''
        User sgiath
        Port 22
        Protocol 2

        PasswordAuthentication yes
        ChallengeResponseAuthentication yes
        PubkeyAuthentication yes
        PreferredAuthentications publickey

        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
        KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
        HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa
        MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
      '';

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
        "vesta.local".hostname = "192.168.1.2";
        "vesta.sgiath.dev" = {
          hostname = "193.165.30.198";
          port = 2200;
        };

        # Router
        "turris.sgiath.dev" = {
          hostname = "192.168.1.1";
          user = "root";
        };

        # NAS
        "nas.local".hostname = "192.168.1.4";

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
      };
    };
  };
}

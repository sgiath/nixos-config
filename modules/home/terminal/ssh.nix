{ config, lib, ... }:
{
  config = lib.mkIf config.programs.ssh.enable {
    home.file = {
      ".ssh/personal_pgp.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGJYz3V8IxqdAJw9LLj0RMsdCu4QpgPmItoDoe73w/3 openpgp:0xB94CDF85
      '';

      ".ssh/remote_pgp.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILxh2qujFEDOb0S69C97cmIDT4rma0tmvT3M5cHF2sg1 openpgp:0x6428E2A2
      '';
    };

    programs.ssh = {
      enableDefaultConfig = false;

      settings = {
        # git
        "github.com" = {
          HostName = "github.com";
          User = "git";
        };
        "sr.ht" = {
          HostName = "git.sr.ht";
          User = "git";
        };
        "gitlab.com" = {
          User = "git";
          IdentitiesOnly = "yes";
          IdentityFile = "~/.ssh/remote_pgp.pub";
        };

        # servers
        "vesta.sgiath.dev" = {
          HostName = "193.165.30.198";
          Port = 2200;
        };

        # local network
        "turris.local" = {
          HostName = "192.168.1.1";
          User = "root";
          IdentityFile = "~/.ssh/personal_pgp.pub";
          IdentitiesOnly = "yes";
        };
        "vesta.local" = {
          HostName = "192.168.1.2";
          IdentityFile = "~/.ssh/personal_pgp.pub";
          IdentitiesOnly = "yes";
        };
        "nas.local" = {
          HostName = "192.168.1.4";
          IdentityFile = "~/.ssh/personal_pgp.pub";
          IdentitiesOnly = "yes";
        };
        "ceres.local".HostName = "192.168.1.6";

        # CrazyEgg
        "scramble.crazyegg.com" = {
          HostName = "172.30.4.10";
          User = "ubuntu";
          ProxyJump = "bastion.crazyegg.com";
        };
        "bastion.crazyegg.com" = {
          HostName = "us-east-1.general-purpose.bastion.crazyegg.com";
          User = "filip";
          ProxyCommand = "none";
          ForwardAgent = true;
        };
        "i.*.crazyegg.com" = {
          User = "crazyegg";
          ProxyJump = "bastion.crazyegg.com";
        };

        # defaults
        "*" = {
          User = "sgiath";
          Compression = true;
          ServerAliveInterval = 60;
          ServerAliveCountMax = 30;
          Protocol = "2";
          HashKnownHosts = "yes";

          PasswordAuthentication = "yes";
          ChallengeResponseAuthentication = "yes";
          PubkeyAuthentication = "yes";
          PreferredAuthentications = "publickey";

          Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr";
          KexAlgorithms = "curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256";
          HostKeyAlgorithms = "ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa,ecdsa-sha2-nistp521-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp521,ecdsa-sha2-nistp384,ecdsa-sha2-nistp256";
          MACs = "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com";
        };
      };
    };
  };
}

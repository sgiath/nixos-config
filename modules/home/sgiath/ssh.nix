{ config, lib, ... }:
{
  config = lib.mkIf config.programs.ssh.enable {
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
        };
        "vesta.local".HostName = "192.168.1.2";
        "nas.local".HostName = "192.168.1.4";
        "ceres.local".HostName = "192.168.1.6";

        # CrazyEgg
        "scramble.crazyegg.com" = {
          HostName = "ec2-3-82-224-38.compute-1.amazonaws.com";
          User = "ubuntu";
        };
        "bastion.crazyegg.com" = {
          HostName = "us-east-1.general-purpose.bastion.crazyegg.com";
          User = "filip";
          ProxyCommand = "none";
          ForwardAgent = true;
        };
        "i.*.crazyegg.com" = {
          User = "crazyegg";
          ProxyCommand = "ssh bastion.crazyegg.com -W %h:%p";
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

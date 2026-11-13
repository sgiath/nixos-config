{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    security = {
      sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };

      doas = {
        enable = true;
        wheelNeedsPassword = false;
      };
    };

    environment.shellAliases.sudo = "doas";

    services = {
      openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
        };
      };
    };

    programs.ssh = {
      pubkeyAcceptedKeyTypes = [
        "ssh-ed25519"
        "ssh-rsa"
      ];
      ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
        "aes256-ctr"
        "aes192-ctr"
        "aes128-ctr"
      ];
      kexAlgorithms = [
        "curve25519-sha256@libssh.org"
        "ecdh-sha2-nistp521"
        "ecdh-sha2-nistp384"
        "ecdh-sha2-nistp256"
        "diffie-hellman-group-exchange-sha256"
      ];
      hostKeyAlgorithms = [
        "ssh-ed25519-cert-v01@openssh.com"
        "ssh-rsa-cert-v01@openssh.com"
        "ssh-ed25519"
        "ssh-rsa"
      ];
      macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
        "hmac-sha2-512"
        "hmac-sha2-256"
        "umac-128@openssh.com"
      ];

      # Hosts reach each other unattended (CrazyEgg home repository sync,
      # home/bin/inbox peers, `update` probing and deploying over Nebula), so
      # their host keys are known up front.
      knownHosts = {
        ceres = {
          hostNames = [
            "ceres"
            "ceres.nebula.sgiath.dev"
          ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJqiRijmcUIZlOBesuAGoZJquV2wYOSe00GEaLGgXOKm";
        };
        vesta = {
          hostNames = [
            "vesta"
            "vesta.nebula.sgiath.dev"
          ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbclzr8Y1+/RCB5bsgzgZndcAPRCtQBgA8YBc1uEWm5";
        };
        pallas = {
          hostNames = [
            "pallas"
            "pallas.nebula.sgiath.dev"
          ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIIJi+z7rA4XFNVKVqJhoX+cRJ/LORCSZ6pYPoZ9p3Vc";
        };
      };
    };
  };
}

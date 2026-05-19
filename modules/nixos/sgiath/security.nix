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
    };
    macs = [
      "hmac-sha2-512-etm@openssh.com"
      "hmac-sha2-256-etm@openssh.com"
      "umac-128-etm@openssh.com"
      "hmac-sha2-512"
      "hmac-sha2-256"
      "umac-128@openssh.com"
    ];
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.programs.gpg.enable {
    services = {
      gpg-agent = {
        enable = true;
        enableSshSupport = true;
        enableZshIntegration = true;
        pinentry.package = pkgs.pinentry-gnome3;
        sshKeys = [
          # personal
          "191203A373DD9867A125EC6A9D3EC96416186FEE"
          # Remote
          "E89D59DFD32593A357E4DDB873DD6F945A928196"
        ];
      };
    };

    # Work around a Home Manager unit cycle with gpg-agent-ssh.socket.
    # Remove once upstream no longer adds socket ordering/wants here.
    systemd.user.services."set-SSH_AUTH_SOCK" = {
      Install.WantedBy = lib.mkForce [ "default.target" ];
      Unit.Before = lib.mkForce [ ];
    };

    programs.gpg = {
      publicKeys = [
        # personal
        {
          text = ''
            -----BEGIN PGP PUBLIC KEY BLOCK-----

            mDMEXD878hYJKwYBBAHaRw8BAQdAwqrLJCRBI9FXY7lVhHr4TyKcN60n0d5UwOZ4
            xlOENC60JUZpbGlwIFZhdmVyYSA8RmlsaXBWYXZlcmFAc2dpYXRoLmRldj6IkwQT
            FgoAOwIbAQULCQgHAwUVCgkICwUWAgMBAAIeAQIXgBYhBLFmNiTQk2iO1cMpa3D5
            x940yzvIBQJclU/3AhkBAAoJEHD5x940yzvIIgsA/3ZBTzl70feIKECVskOUL67m
            CLO8JjvCYWbDGBO3yKcnAP0clJkwNkym4h2d64Hi1O03tKA7IV7YFB3Pj4SIXJmm
            CLQgRmlsaXAgVmF2ZXJhIDxGaWxpcFZhdmVyYUBwbS5tZT6IgQQTFgoAKRYhBLFm
            NiTQk2iO1cMpa3D5x940yzvIBQJqKXBsAhsBAhYAAh4BAheAAAoJEHD5x940yzvI
            nzwBAJqWsl+DfGVzj294ZxNnI6tAHgEi8QGHs2hap0Ezls76AP4mm3ClquzCJdc6
            Z6/cXxActDBrW3RpQ8rRzau2LDdoD7gzBFw/PrIWCSsGAQQB2kcPAQEHQLYGg23s
            h4UZKiY/9hlhP41VjimAGoiG9cUVgJYfBNnniO8EGBYKACACGwIWIQSxZjYk0JNo
            jtXDKWtw+cfeNMs7yAUCXHajLACBdiAEGRYKAB0WIQQsUBatGCGn6sLrGnoPRbS8
            R7RGlwUCXD8+sgAKCRAPRbS8R7RGl+V5AP485PEx3fP5tzTPaP1eNwCKLA/fKNuI
            3UicRNkOL0hdQQD+KVHDDXG2L9ONEMek/p5piRVdRbXrN/+4M8PfHrlrZA8JEHD5
            x940yzvIJMUBAIGnTzlxfmW4sk6vMImln3VAZyRH+c5/JK5FgZmPIEC4AQDKRFQ+
            UXtxNikQzc0yTLyl/YDA/FwSJFgEaVOMURZiBLg4BFw/PtUSCisGAQQBl1UBBQEB
            B0CKkqDk75gH1ALXTJukK1YQ/237EjhWdZiFFynL+JpRbgMBCAeIeAQYFgoAIAIb
            DBYhBLFmNiTQk2iO1cMpa3D5x940yzvIBQJcdqMsAAoJEHD5x940yzvIkR8BAMSv
            75GOTJ3tgjEWjp5ivcZEjCrzzER6vXD5qE3bJFviAQCB2tXFjgh68Im7jBZcTPOc
            TkEw+zMm5e2nbd8KX5SSDbgzBFw/QaoWCSsGAQQB2kcPAQEHQOGJYz3V8IxqdAJw
            9LLj0RMsdCu4QpgPmItoDoe73w/3iHcEGBYKACACGyAWIQSxZjYk0JNojtXDKWtw
            +cfeNMs7yAUCXHajLAAKCRBw+cfeNMs7yPWzAPj8p5A0mQp5t43s5ppFppAmhHgA
            cyCOEuwZbJzRBgORAQDi88X5JFBa18SEZ1KcoxwHoHYBzmQEhf0kQ3KV43jwAg==
            =hRQY
            -----END PGP PUBLIC KEY BLOCK-----
          '';
          trust = 5;
        }

        # Remote
        {
          text = ''
            -----BEGIN PGP PUBLIC KEY BLOCK-----

            mDMEakWKphYJKwYBBAHaRw8BAQdAvGHaq6MUQM5vRLr0L3tyYgNPiuZrS2a9Pczl
            wcXayDW0JkZpbGlwIFZhdmVyYSA8ZmlsaXAudmF2ZXJhQHJlbW90ZS5jb20+iK8E
            ExYKAFcWIQT2ED24vf2DLrnQBydySUwsZCjiogUCakWKphsUgAAAAAAEAA5tYW51
            MiwyLjUrMS4xMiwwLDMCGyMFCwkIBwICIgIGFQoJCAsCBBYCAwECHgcCF4AACgkQ
            cklMLGQo4qJEKAEAxfdlptVHyNN9donJ2Smo9CeGvHfKoFvF/dChx//JrH0BAOi/
            Ew5DrpQSalSDpgjXVRcSqGX1XbpnPJ+yzMXfO+UM
            =Cf0g
            -----END PGP PUBLIC KEY BLOCK-----
          '';
          trust = 5;
        }
      ];

      gpgsmSettings = {
        with-key-data = true;
        with-keygrip = true;
        with-secret = true;
      };

      settings = {
        default-key = "0x70F9C7DE34CB3BC8";
        trusted-key = "0x70F9C7DE34CB3BC8";
        no-emit-version = true;
        no-comments = true;
        no-greeting = true;
        no-symkey-cache = true;
        expert = true;
        keyid-format = "0xlong";
        with-fingerprint = true;
        with-keygrip = true;
        list-options = [
          "show-uid-validity"
          "show-unusable-subkeys"
        ];
        verify-options = [ "show-uid-validity" ];
        require-cross-certification = true;
        throw-keyids = true;
        ignore-time-conflict = true;
        allow-freeform-uid = true;
        use-agent = true;
        charset = "utf-8";
        fixed-list-mode = true;
        utf8-strings = true;
        auto-key-import = true;
        include-key-block = true;
        personal-cipher-preferences = [
          "AES256"
          "CAMELLIA256"
        ];
        personal-digest-preferences = [
          "SHA512"
          "SHA384"
          "SHA256"
        ];
        personal-compress-preferences = [
          "ZLIB"
          "BZIP2"
          "ZIP"
          "Uncompressed"
        ];
        default-preference-list = [
          "SHA512"
          "SHA384"
          "SHA256"
          "AES256"
          "CAMELLIA256"
          "ZLIB"
          "BZIP2"
          "ZIP"
          "Uncompressed"
        ];
        cert-digest-algo = "SHA512";
        s2k-digest-algo = "SHA512";
        digest-algo = "SHA512";
        s2k-cipher-algo = "AES256";
        cipher-algo = "AES256";
        compress-algo = "zlib";
      };
    };
  };
}

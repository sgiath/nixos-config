{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.programs.gpg.enable {
    services = {
      ssh-agent.enable = true;
      gpg-agent = {
        enable = true;
        enableSshSupport = true;
        enableZshIntegration = true;
        pinentry.package = pkgs.pinentry-gnome3;
        sshKeys = [ "191203A373DD9867A125EC6A9D3EC96416186FEE" ];
      };
    };
    programs.gpg = {
      settings = {
        default-key = "0x70F9C7DE34CB3BC8";
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

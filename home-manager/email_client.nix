{ config, lib, pkgs, ... }:

{
  options.sgiath.claws = { enable = lib.mkEnableOption "Claws Email"; };

  config = lib.mkIf config.sgiath.claws.enable {
    home = {
      packages = [ pkgs.claws-mail ];

      file.".signature".text = ''
        Filip Vavera

        https://sgiath.dev
        GPG: 0x70F9C7DE34CB3BC8

        Why is HTML email a security nightmare? See https://useplaintext.email/
      '';
    };
  };
}

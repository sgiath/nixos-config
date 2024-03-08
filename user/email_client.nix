{ config, pkgs, ... }:

{
  home = {
    packages = [ pkgs.claws-mail ];
    file.".mail-signature".text = ''
      Filip Vavera

      https://sgiath.dev
      GPG: 0x70F9C7DE34CB3BC8
     
      Why is HTML email a security nightmare? See https://useplaintext.email/
    '';
  };
}

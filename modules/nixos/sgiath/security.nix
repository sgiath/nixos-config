{
  config,
  lib,
  pkgs,
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

    programs = {
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryPackage = pkgs.pinentry-gnome3;
      };
      ssh.startAgent = false;
    };
    hardware.gpgSmartcards.enable = true;
  };
}

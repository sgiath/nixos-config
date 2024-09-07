{ config, lib, ... }:
{
  options.sgiath.mailserver = {
    enable = lib.mkEnableOption "mailserver";
  };

  config = lib.mkIf config.sgiath.mailserver.enable {
    mailserver = {
      enable = true;
      certificateScheme = "acme-nginx";
      fqdn = "mail.sgiath.dev";
      domains = [ "sgiath.dev" ];
      loginAccounts = {
        sgiath = {
          name = "sgiath@sgiath.dev";
          hashedPassword = "";
          aliases = "@sgiath.dev";
        };
      };
      dmarcReporting = {
        enable = true;
        domain = "sgiath.dev";
        organizationName = "sgiath";
      };
      rebootAfterKernelUpgrade.enable = true;
    };
  };
}

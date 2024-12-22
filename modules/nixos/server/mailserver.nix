{ config, lib, ... }:
{
  options.sgiath.mailserver = {
    enable = lib.mkEnableOption "mailserver";
  };

  config = lib.mkIf (config.sgiath.server.enable && config.mailserver.enable) {
    mailserver = {
      fqdn = "mail.sgiath.dev";
      domains = [ "sgiath.dev" ];

      loginAccounts = {
        sgiath = {
          name = "sgiath@sgiath.dev";
          hashedPassword = "$2b$05$zgIJxgbkY3aidH2iyA/Z5.yoruyLUERJVxslMsapnm2uNE5NBh57O";
          aliases = [ "@sgiath.dev" ];
        };
      };

      dmarcReporting = {
        enable = true;
        domain = "sgiath.dev";
        organizationName = "sgiath";
      };

      certificateScheme = "acme-nginx";
      rebootAfterKernelUpgrade.enable = true;
    };
  };
}

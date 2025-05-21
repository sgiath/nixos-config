{config, lib, ...}:
{
  config = lib.mkIf config.sgiath.server.enable && config.services.gitlab.enable {
    services = {
      gitlab = {
        host = "gitlab.sgiath.dev";
        https = true;

        initialRootEmail = "admin@sgiath.dev";
        initialRootPasswordFile = "/data/gitlab-passwd";
      };

      nginx.virtualHosts."gitlab.sgiath.dev" = {
        # SSL
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;
      };
    };
  };
}

{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.jitsi-meet.enable) {
    services = {
      jitsi-meet = {
        hostName = "meet.sgiath.dev";

        nginx.enable = true;
        prosody.enable = true;
      };

      nginx.virtualHosts."meet.sgiath.dev" = {
        # SSL
        onlySSL = true;
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

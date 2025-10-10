{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.kanboard.enable) {
    services = {
      kanboard = {
        domain = "board.sgiath.dev";
        nginx = {
          # SSL
          kTLS = true;
  
          # ACME
          enableACME = true;
          acmeRoot = null;
  
          # QUIC
          http3_hq = true;
        };
      };
    };
  };
}

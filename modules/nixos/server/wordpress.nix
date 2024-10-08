{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable) {
    services = {
      nginx.virtualHosts."wp.sgiath.dev" = {
        # SSL
        onlySSL = true;
        enableACME = true;
        kTLS = true;

        # QUIC
        http3_hq = true;
        quic = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8081";
        };
      };
    };
  };
}

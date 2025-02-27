{ config, lib, ... }:
{
  options.services.focalboard.enable = lib.mkEnableOption "focalboard";

  config = lib.mkIf (config.sgiath.server.enable && config.services.focalboard.enable) {

    services.nginx.virtualHosts."focalboard.sgiath.dev" = {
      # SSL
      onlySSL = true;
      kTLS = true;

      # ACME
      enableACME = true;
      acmeRoot = null;

      # QUIC
      http3_hq = true;
      quic = true;

      locations."/" = {
        proxyWebsockets = true;
        proxyPass = "http://127.0.0.1:8453";
      };
    };

    virtualisation.oci-containers.containers.focalboard = {
      image = "mattermost/focalboard";
      ports = [
        "8453:8000"
      ];
    };
  };
}

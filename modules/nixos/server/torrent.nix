{
  config,
  lib,
  pkgs,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.transmission.enable) {
    services = {
      transmission = {
        openPeerPorts = true;
        performanceNetParameters = true;
        package = pkgs.transmission_4;
        webHome = pkgs.flood-for-transmission;

        settings = {
          download-dir = "/nas/downloads";
          rpc-authentication-required = true;
          rpc-username = "sgiath";
          rpc-password = secrets.transmission;
        };
      };

      nginx.virtualHosts."torrent.sgiath.dev" = {
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
          proxyPass = "http://127.0.0.1:9091";
          proxyWebsockets = true;
        };
      };
    };
  };
}


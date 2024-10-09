{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.dnd5etools = {
    enable = lib.mkEnableOption "5e tools service";
  };

  config = lib.mkIf (config.sgiath.server.enable && config.services.dnd5etools.enable) {
    services.nginx.virtualHosts."5e.sgiath.dev" = {
      # SSL
      onlySSL = true;
      kTLS = true;

      # ACME
      enableACME = true;
      acmeRoot = null;

      # QUIC
      http3_hq = true;
      quic = true;

      # static files
      root = "${pkgs.dnd5etools}";
      # locations."/".root = "${pkgs.dnd5etools}";
    };
  };
}

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
      enableACME = true;
      kTLS = true;

      # QUIC
      http3_hq = true;
      quic = true;

      # static files
      locations."/".root = "${pkgs.dnd5etools}";
    };
  };
}

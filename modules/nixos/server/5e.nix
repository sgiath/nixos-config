{ pkgs, ... }:
{
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
}

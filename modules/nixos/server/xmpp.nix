{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.xmpp.enable) {
    services = {
      prosody = {
      enable = true;
    };
    };
  };
}

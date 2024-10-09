{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.jitsi-meet.enable) {
    services.jitsi-meet = {
      hostName = "meet.sgiath.dev";

      nginx.enable = true;
      prosody.enable = true;
    };
  };
}

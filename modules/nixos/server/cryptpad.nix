{
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.sgiath.server.enable {
    services.cryptpad = {
      configureNginx = true;
      settings = {
        httpSafeOrigin = "https://cryptpad-safe.sgiath.dev";
        httpUnsafeOrigin = "https://cryptpad.sgiath.dev";
      };
    };
  };
}

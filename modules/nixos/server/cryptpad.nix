{
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.sgiath.server.enable {
    services = {
      cryptpad = {
        configureNginx = true;
        settings = {
          httpPort = 3001;
          httpSafeOrigin = "https://cryptpad-safe.sgiath.dev";
          httpUnsafeOrigin = "https://cryptpad.sgiath.dev";
        };
      };
      nginx.virtualHosts = {
        "cryptpad.sgiath.dev".acmeRoot = null;
        "cryptpad-safe.sgiath.dev".acmeRoot = null;
      };
    };
  };
}

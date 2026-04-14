{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.enable && config.services.ollama.enable) {
    services.ollama = {
      package = pkgs.ollama-rocm;
      host = "0.0.0.0";
      rocmOverrideGfx = "10.3.0";
      environmentVariables = {
        # allow external usage
        OLLAMA_ORIGINS = "*";
      };
    };
  };
}

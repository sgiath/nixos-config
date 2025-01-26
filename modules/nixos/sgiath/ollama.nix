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
      # package = pkgs.ollama;
      # acceleration = "rocm";
      host = "0.0.0.0";
      environmentVariables = {
        # run on GPU
        HSA_OVERRIDE_GFX_VERSION = "10.3.0";
        HCC_AMDGPU_TARGET = "gfx1030";

        # allow external usage
        OLLAMA_ORIGINS = "*";
      };
    };
  };
}

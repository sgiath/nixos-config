{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf config.services.comfyui.enable {
    services.comfyui = {
      gpuSupport = "rocm";
      enableManager = true;
      extraArgs = [
        "--disable-xformers"
        "--use-pytorch-cross-attention"
      ];
    };
  };
}

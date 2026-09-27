{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.services.comfyui.enable {
    services.comfyui = {
      gpuSupport = "rocm";
      # The upstream module defaults to comfyui-nix's own packages, bypassing
      # overlays/comfyui (INT8 probe patch, prompt-enhancer Python deps).
      package = pkgs.comfy-ui-rocm;
      extraArgs = [
        "--disable-xformers"
        "--use-pytorch-cross-attention"
      ];

      # Keep the bundled collection disabled; hosts opt into individual custom nodes.
      bundledCustomNodes = false;
    };
  };
}

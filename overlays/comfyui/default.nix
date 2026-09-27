{ inputs, ... }:
final: prev:
let
  comfyui-nix = inputs.comfyui;

  # The nixpkgs comfyui-nix pins, so python-overrides.nix keeps matching the package set
  # it was written against and the unchanged derivations share store paths with upstream.
  pkgs = import comfyui-nix.inputs.nixpkgs {
    inherit (prev.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      allowBrokenPredicate = pkg: (pkg.pname or "") == "open-clip-torch";
    };
  };

  versions = import "${comfyui-nix}/nix/versions.nix";
  gpuSupport = "rocm";
in
{
  # x86_64-linux only, like upstream: pytorch.org ships no ROCm wheel for aarch64.
  comfy-ui-rocm =
    if prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64 then
      (import "${comfyui-nix}/nix/packages.nix" {
        inherit versions gpuSupport;
        pkgs = pkgs // {
          # Probe ROCm INT8 GEMM support before selecting native quantized ops.
          applyPatches =
            args:
            pkgs.applyPatches (
              args
              // {
                patches = (args.patches or [ ]) ++ [ ./rocm-int8-compute.patch ];
              }
            );
        };
        inherit (pkgs) lib;
        # Optional json_repair fallback of ComfyUI-Qwen-Image-2.1-Prompt-Enhancer (ceres).
        extraPythonPackages = ps: [ ps.json-repair ];
        pythonOverrides = import "${comfyui-nix}/nix/python-overrides.nix" {
          inherit pkgs versions gpuSupport;
        };
      }).default
    else
      prev.comfy-ui-rocm;
}

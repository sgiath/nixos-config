{ inputs, ... }:
final: prev:
let
  comfyui-nix = inputs.comfyui;
  upstream = import "${comfyui-nix}/nix/versions.nix";

  # https://github.com/benjiyaya/ComfyUI-Qwen-Image-2.1-Prompt-Enhancer/

  # Qwen Image 2.1 landed in ComfyUI v0.37.0 (QwenImage21 in comfy/supported_models.py)
  # while comfyui-nix's newest tag is v0.34.0. Between those releases requirements.txt
  # only moved the Comfy-Org PyPI pins, so swap the source and those wheels and keep the
  # pre-built ROCm torch runtime comfyui-nix already assembles.
  versions = upstream // {
    comfyui = {
      version = "0.37.0";
      releaseDate = "2026-09-21T07:35:01Z";
      rev = "73c9bad4d21e7addbe1d13bc92eee0f1431b017d";
      hash = "sha256-hfpoQsu8xzKHCy2Qqw2BMGsorwizJEuhKXWjUUJzTHs=";
    };

    vendored = upstream.vendored // {
      frontendPackage = {
        version = "1.52.7";
        url = "https://files.pythonhosted.org/packages/a8/1e/835f8b0396645a28266a87eeda6392f461a2ef87391cbf729ef9a7ae5d75/comfyui_frontend_package-1.52.7-py3-none-any.whl";
        hash = "sha256-OqViT6UIX4Rh0xt+uIpC7Wmg54OjW+wcKjO5D8dmCVA=";
      };

      # comfyui-workflow-templates 0.11.66 pins these companion bundles exactly
      # (Requires-Dist); media-api/video/image/other are unchanged from upstream.
      workflowTemplates = {
        version = "0.11.66";
        url = "https://files.pythonhosted.org/packages/f3/40/437f91c26e198dfc4bcad70efec1a91d79068dd78ed76fc57130c08b650d/comfyui_workflow_templates-0.11.66-py3-none-any.whl";
        hash = "sha256-KvmT6Eu1qJ5muoRpdUDPIVCTAjxKDABP9Mwr4CN6GY4=";
      };

      workflowTemplatesCore = {
        version = "0.3.357";
        url = "https://files.pythonhosted.org/packages/b7/eb/e6236ad859a7db133e02d51f79711626f88863b6f165cba77f3a6b5afa48/comfyui_workflow_templates_core-0.3.357-py3-none-any.whl";
        hash = "sha256-+o2u8mZaHYWUvvU6WP+8R6B4j8O72LaLSmrWxisbQDM=";
      };

      workflowTemplatesJson = {
        version = "0.1.92";
        url = "https://files.pythonhosted.org/packages/c7/c6/9fa43666d27e4a33243cd24721e94bf978649a7ea7d8d0b9eb498cc0da3e/comfyui_workflow_templates_json-0.1.92-py3-none-any.whl";
        hash = "sha256-aA3ZBSX67rQdvNZyTGAGUT1ge3w6QYqxc/qFDIPckbE=";
      };

      workflowTemplatesMediaAssets01 = {
        version = "0.1.47";
        url = "https://files.pythonhosted.org/packages/b2/a5/d091abf1e0e0c81debc29337be3308d3bbbaf477ef223aeee9e46454c264/comfyui_workflow_templates_media_assets_01-0.1.47-py3-none-any.whl";
        hash = "sha256-ga/4qp+RHYbYuors2MDVgNZoCf9C5KUdaAqQj6/tiD0=";
      };

      # New media bundle since the comfyui-nix pin; wired in through pythonOverrides below.
      workflowTemplatesMediaAssets02 = {
        version = "0.1.3";
        url = "https://files.pythonhosted.org/packages/cf/8e/17af57c9e3cb120e43fc19dff9a34b357c8ae6eb23e08785d7d697afc9d3/comfyui_workflow_templates_media_assets_02-0.1.3-py3-none-any.whl";
        hash = "sha256-hZLANvYLTxgHXxdz2+PTkc/JZ/fc97QUPsRvyS6wr3o=";
      };

      embeddedDocs = {
        version = "0.5.12";
        url = "https://files.pythonhosted.org/packages/ba/13/b57fb0de3eb1bcef0b6e26444ab357a8d6a18d859d58245c4a6307ca82e3/comfyui_embedded_docs-0.5.12-py3-none-any.whl";
        hash = "sha256-kEKdjRfqXYX53gC8wlzU4rxhSqPWwDzOvzKuxlsQeoA=";
      };

      comfyKitchen = {
        version = "0.2.35";
        any = {
          url = "https://files.pythonhosted.org/packages/14/60/8f075cceb07cb78d3792446b1156b7f5a41b260ac60645ef1483e34f71ce/comfy_kitchen-0.2.35-py3-none-any.whl";
          hash = "sha256-+V1IY4rdGjbu0UA3ggwPhfDfdlMh7rU/B1C++JBqvL4=";
        };
        linuxX86_64 = {
          url = "https://files.pythonhosted.org/packages/8b/c5/13b976741bc3b35f3a7fcded995c5a774dccfe69aee0e792a0381378777c/comfy_kitchen-0.2.35-cp312-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
          hash = "sha256-nFnomBAdJlf5Z5EKz2q8b3ctdrlF2obF/aX32BfRzaE=";
        };
      };

      comfyAimdo = {
        version = "0.5.5";
        any = {
          url = "https://files.pythonhosted.org/packages/be/52/3ae1892775f0138af1c0cc27341cf073e0890731f0c68848e8831738f9c2/comfy_aimdo-0.5.5-py3-none-any.whl";
          hash = "sha256-IItDeaCA1qeNtJ5iNnUWQrjp4JjuJwsDWhdA7CGDn70=";
        };
        linuxX86_64 = {
          url = "https://files.pythonhosted.org/packages/5d/18/807dd84d80469c9620928429911b9ff04c699e8b47204423a8804ac3f09d/comfy_aimdo-0.5.5-cp39-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
          hash = "sha256-ek3HaDEnOi+Df2fPScnlB+d4sZr/F+bvijSm6WlP2Go=";
        };
      };
    };
  };

  # The nixpkgs comfyui-nix pins, so python-overrides.nix keeps matching the package set
  # it was written against and the unchanged derivations share store paths with upstream.
  pkgs = import comfyui-nix.inputs.nixpkgs {
    inherit (prev.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      allowBrokenPredicate = pkg: (pkg.pname or "") == "open-clip-torch";
    };
  };

  gpuSupport = "rocm";
in
{
  # x86_64-linux only, like upstream: pytorch.org ships no ROCm wheel for aarch64.
  comfy-ui-rocm =
    if prev.stdenv.isLinux && prev.stdenv.isx86_64 then
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
        # Extend here so the ROCm launcher fix below also covers the enhancer runtime.
        extraPythonPackages = ps: [ ps.json-repair ];
        pythonOverrides =
          final: prev:
          (import "${comfyui-nix}/nix/python-overrides.nix" {
            inherit pkgs versions gpuSupport;
          })
            final
            prev
          // {
            # vendored-packages.nix hardcodes the umbrella's companion list, which
            # predates media-assets-02. The umbrella's Requires-Dist pins it, so the
            # nixpkgs runtime-deps check fails without it and templates from that
            # bundle raise FileNotFoundError at runtime. mkWheel builds through
            # python.pkgs.buildPythonPackage, so intercept that one call here.
            buildPythonPackage = prev.buildPythonPackage // {
              __functor =
                _: args:
                prev.buildPythonPackage (
                  if (args.pname or null) == "comfyui-workflow-templates" then
                    args
                    // {
                      propagatedBuildInputs = args.propagatedBuildInputs ++ [
                        (prev.buildPythonPackage {
                          pname = "comfyui-workflow-templates-media-assets-02";
                          inherit (versions.vendored.workflowTemplatesMediaAssets02) version;
                          format = "wheel";
                          src = pkgs.fetchurl { inherit (versions.vendored.workflowTemplatesMediaAssets02) url hash; };
                          doCheck = false;
                        })
                      ];
                    }
                  else
                    args
                );
            };
          };
      }).default.overrideAttrs
        (old: {
          # The launcher puts /run/opengl-driver/lib first on LD_LIBRARY_PATH so host GPU
          # userland beats Nix-bundled libraries. Here that replaces the ROCm 7.1 runtime
          # inside the torch wheel with the host's clr 7.2.3, whose rocm-runtime wants glibc
          # 2.42 symbols (GLIBC_ABI_GNU2_TLS) the glibc 2.40 this python env links against
          # lacks, and torch fails to import. The wheel carries a complete ROCm runtime and
          # only needs /dev/kfd, so the host prefix goes.
          postFixup = (old.postFixup or "") + ''
            launcher=$(readlink "$out/bin/comfy-ui")
            rm "$out/bin/comfy-ui" "$out/bin/comfyui"
            substitute "$launcher" "$out/bin/comfy-ui" \
              --replace-fail 'export LD_LIBRARY_PATH="/run/opengl-driver/lib:$LD_LIBRARY_PATH"' ':'
            chmod +x "$out/bin/comfy-ui"
            ln -s comfy-ui "$out/bin/comfyui"
          '';
        })
    else
      prev.comfy-ui-rocm;
}

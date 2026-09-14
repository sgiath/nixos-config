{ lib, ... }:
{
  imports = [
    ./dgx-spark.nix
    ./gpu.nix
    ./gpu-amd.nix
    ./gpu-nvidia.nix
    ./razer.nix
  ];

  options.sgiath.hardware = {
    gpu = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "amd"
          "nvidia"
        ]
      );
      default = null;
      example = "amd";
      description = "What GPU configuration to use";
    };

    boot = lib.mkOption {
      type = lib.types.enum [
        "uefi"
        "legacy"
      ];
      default = "uefi";
      example = "legacy";
    };

    razer.enable = lib.mkEnableOption "Razer notebook";
    dgx-spark.enable = lib.mkEnableOption "NVIDIA DGX Spark (GB10) platform";
  };
}

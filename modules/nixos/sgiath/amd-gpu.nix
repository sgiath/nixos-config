{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.enable && (config.sgiath.gpu == "amd")) {
    boot.kernelModules = [ "kvm-amd" ];
    services.xserver.videoDrivers = [ "amdgpu" ];

    environment = {
      systemPackages = with pkgs.rocmPackages; [
        pkgs.clinfo
        rocminfo
        rocm-smi
        clr
      ];
      sessionVariables = {
        AMD_VULKAN_ICD = "RADV";
        RADV_PERFTEST = "nofibril";
      };
    };

    hardware = {
      amdgpu = {
        initrd.enable = true;
        opencl.enable = true;
      };
    };
  };
}

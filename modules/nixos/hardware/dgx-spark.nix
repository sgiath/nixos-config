{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.hardware.dgx-spark.enable {
    # graham33/nixos-dgx-spark: NVIDIA 6.17 kernel, open nvidia driver, CUDA
    # (sm_120/121), podman + nvidia-container-toolkit, ConnectX-7 hot-plug,
    # unlimited memlock for RDMA, Flox CUDA cache, DGX Dashboard on :11000.
    # It sets boot.kernelPackages; hosts using it must not set their own kernel.
    hardware.dgx-spark.enable = true;

    # Identical on every Spark: single NVMe, USB boot media.
    boot.initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "usb_storage"
      "uas"
      "sd_mod"
    ];

    # 128 GB unified memory; the 24 GB cap from common/nix.nix would OOM-kill
    # the NVIDIA kernel and CUDA package builds that are not in any cache.
    systemd.services.nix-daemon.serviceConfig = {
      MemoryMax = lib.mkForce "96G";
      MemoryHigh = lib.mkForce "80G";
    };
  };
}

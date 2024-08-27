{
  imports = [ ./hardware.nix ];

  networking.hostName = "ceres";

  sgiath = {
    amd-gpu.enable = true;
    nvidia-gpu.enable = false;
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    gaming.enable = true;
    networking.localDNS.enable = true;
    printing.enable = true;
    razer.enable = false;
    wayland.enable = true;
  };

  crazyegg.enable = true;
}

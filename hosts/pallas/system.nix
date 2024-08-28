{
  imports = [ ./hardware.nix ];

  networking.hostName = "pallas";

  sgiath = {
    amd-gpu.enable = false;
    nvidia-gpu.enable = true;
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    gaming.enable = true;
    networking.localDNS.enable = false;
    printing.enable = true;
    razer.enable = true;
    wayland.enable = true;
  };

  crazyegg.enable = true;
}

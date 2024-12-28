{
  imports = [ ./hardware.nix ];

  networking.hostName = "pallas";
  networking.wireless.enable = true;
  # environment.systemPackages = with pkgs; [ wpa_supplicant_gui ];

  sgiath = {
    enable = true;
    gpu = "nvidia";
    audio.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    xamond.enable = false;
    printing.enable = true;
    razer.enable = true;
    wayland.enable = true;
  };

  services = { };

  crazyegg.enable = true;
}

{
  imports = [
    # always enabled
    ./boot.nix
    ./mounting_usb.nix
    ./networking.nix
    ./optimizations.nix
    ./security.nix
    ./stylix.nix
    ./time_lang.nix
    ./udev.nix

    # enable switch
    ./amd-gpu.nix
    ./audio.nix
    ./bluetooth.nix
    ./docker.nix
    ./gaming.nix
    ./graphics.nix
    ./nvidia-gpu.nix
    ./printing.nix
    ./razer.nix
    ./wayland.nix

    ./crazyegg
  ];
}

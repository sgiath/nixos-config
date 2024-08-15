{
  imports = [
    # hardware
    ./hardware.nix

    # modules
    ../../nixos

    # work
    ../../work/nginx.nix
  ];

  networking.hostName = "ceres";

  sgiath = {
    audio.enable = true;
    amd-gpu.enable = true;
    bluetooth.enable = true;
    printing.enable = true;
    gaming.enable = true;
    networking.localDNS.enable = true;
    wayland.enable = true;
  };

  services.udev = {
    enable = true;
    extraRules = ''
      # DFU (Internal bootloader for STM32 and AT32 MCUs)
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2e3c", ATTRS{idProduct}=="df11", MODE="0664", GROUP="plugdev"
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0664", GROUP="plugdev"
    '';
  };

  # temporary, move it out
  virtualisation.docker.enable = true;
}

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

      # Trezor
      SUBSYSTEM=="usb", ATTR{idVendor}=="534c", ATTR{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
      KERNEL=="hidraw*", ATTRS{idVendor}=="534c", ATTRS{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

      # Trezor v2
      SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c0", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
      SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
      KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"
    '';
  };

  # temporary, move it out
  virtualisation.docker.enable = true;
}

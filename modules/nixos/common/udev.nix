{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    services.udev = {
      enable = true;
      extraRules = ''
        # DFU (Internal bootloader for STM32 and AT32 MCUs)
        ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2e3c", ATTRS{idProduct}=="df11", MODE="0664", TAG+="uaccess"
        ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0664", TAG+="uaccess"

        # Trezor
        SUBSYSTEM=="usb", ATTR{idVendor}=="534c", ATTR{idProduct}=="0001", MODE="0660", TAG+="uaccess", SYMLINK+="trezor%n"
        KERNEL=="hidraw*", ATTRS{idVendor}=="534c", ATTRS{idProduct}=="0001", MODE="0660", TAG+="uaccess"

        # Trezor v2
        SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c0", MODE="0660", TAG+="uaccess", SYMLINK+="trezor%n"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c1", MODE="0660", TAG+="uaccess", SYMLINK+="trezor%n"
        KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="53c1", MODE="0660", TAG+="uaccess"
      '';
    };
  };
}

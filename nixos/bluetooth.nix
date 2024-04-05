{ config, lib, ... }:

{
  options.sgiath.bluetooth = {
    enable = lib.mkEnableOption "bluetooth";
  };

  config = lib.mkIf config.sgiath.bluetooth.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}

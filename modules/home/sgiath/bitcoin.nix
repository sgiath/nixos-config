{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.bitcoin = {
    enable = lib.mkEnableOption "bitcoin apps";
  };

  config = lib.mkIf (config.sgiath.comm.enable) {
    home.packages = with pkgs; [
      bisq-desktop
      trezor-suite
      trezor-udev-rules
    ];
  };
}

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

  config = lib.mkIf (config.sgiath.bitcoin.enable) {
    home.packages = with pkgs; [
      bisq
      trezor-suite
      trezor-udev-rules
    ];
  };
}

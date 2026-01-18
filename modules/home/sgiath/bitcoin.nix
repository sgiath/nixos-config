{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options.sgiath.bitcoin = {
    enable = lib.mkEnableOption "bitcoin apps";
  };

  config = lib.mkIf (config.sgiath.bitcoin.enable) {
    home.packages = with pkgs; [
      inputs.btc-clients.packages.${pkgs.stdenv.hostPlatform.system}.bisq
      trezor-suite
      trezor-udev-rules
    ];
  };
}

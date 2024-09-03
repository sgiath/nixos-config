{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.audio = {
    enable = lib.mkEnableOption "audio";
  };

  config = lib.mkIf config.sgiath.audio.enable {
    environment.systemPackages = [
      pkgs.hevlum
      pkgs.ffado
    ];

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      wireplumber = {
        enable = true;
        extraConfig.bluetoothEnhancements = {
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.roles" = [
              "hsp_hs"
              "hsp_ag"
              "hfp_hf"
              "hfp_ag"
            ];
          };
        };
      };
    };
  };
}

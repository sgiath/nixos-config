{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  voxtype = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  config = lib.mkIf config.programs.voxtype.enable {
    home.packages = [
      voxtype.rocm
      voxtype.osd-native
    ];

    programs.voxtype = {
      package = voxtype.rocm;
      model.name = "large-v3-turbo";
      service.enable = true;
      settings = {
        hotkey.enabled = false;
        whisper.language = "en";
        meeting = {
          enabled = true;
          audio.loopback_device = "auto";
        };
      };
    };

    wayland.windowManager.hyprland.settings = {
      bind = [
        "$mod, B, exec, ${lib.getExe voxtype.rocm} record start"
      ];
      bindr = [
        "$mod, B, exec, ${lib.getExe voxtype.rocm} record stop"
      ];
    };

    systemd.user.services.voxtype = {
      Service.Environment = "'VOXTYPE_VULKAN_DEVICE=amd' 'HSA_OVERRIDE_GFX_VERSION=10.3.0'";
    };
  };
}

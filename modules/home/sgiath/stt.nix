{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  voxtype = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
in
{
  config = lib.mkIf config.programs.voxtype.enable {
    programs.voxtype = {
      package = voxtype;
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
        "$mod, B, exec, ${lib.getExe voxtype} record start"
      ];
      bindr = [
        "$mod, B, exec, ${lib.getExe voxtype} record stop"
      ];
    };

    systemd.user.services.voxtype = {
      Service.Environment = "VOXTYPE_VULKAN_DEVICE=amd";
    };
  };
}

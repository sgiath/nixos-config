{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  voxtype = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
  toggleCommand = "${lib.getExe voxtype} record toggle";
in
{
  config = lib.mkIf config.programs.voxtype.enable {
    home.packages = [
      inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.osd-native
    ];

    programs.voxtype = {
      package = voxtype;
      model.name = "large-v3-turbo";
      service.enable = true;
      settings = {
        hotkey.enabled = false;
        audio.max_duration_secs = 600;
        whisper.language = "en";
        osd.frontend = "native";
        meeting = {
          enabled = true;
          audio.loopback_device = "auto";
        };
      };
    };

    wayland.windowManager.hyprland.settings = {
      bind = [
        {
          _args = [
            "SUPER + B"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON toggleCommand})")
          ];
        }
      ];
    };
    systemd.user.services.voxtype = {
      Service.Environment = [ "VOXTYPE_VULKAN_DEVICE=amd" ];
    };
  };
}

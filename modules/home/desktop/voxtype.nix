{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  voxtype = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
  startCommand = "${lib.getExe voxtype} record start";
  stopCommand = "${lib.getExe voxtype} record stop";
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
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON startCommand})")
          ];
        }
        {
          _args = [
            "SUPER + B"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON stopCommand})")
            { release = true; }
          ];
        }
      ];
    };
    systemd.user.services.voxtype = {
      Service.Environment = [ "VOXTYPE_VULKAN_DEVICE=amd" ];
    };
  };
}

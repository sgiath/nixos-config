{
  config,
  lib,
  pkgs,
  ...
}:
let
  command = "${lib.getExe pkgs.kitty} --class files -e ${lib.getExe pkgs.superfile}";
in
{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    home.packages = with pkgs; [
      nemo-with-extensions
      nemo-fileroller
      webp-pixbuf-loader

      superfile
      exiftool
    ];

    wayland.windowManager.hyprland.settings.bind = [
      {
        _args = [
          "SUPER + E"
          (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON command})")
        ];
      }
    ];
  };
}

{
  lib,
  pkgs,
  ...
}:
let
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    ${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp} -b 1B1F28CC -c E06B74ff -s C778DD0D -w 2)" - \
      | ${lib.getExe pkgs.satty} \
        --filename - \
        --output-filename "~/Pictures/Screenshots/%Y-%m-%dT%H%M%S.png" \
        --copy-command ${lib.getExe pkgs.wl-copy} \
        --floating-hack
  '';
in
{
  home.packages = [
    screenshot
  ];

  wayland.windowManager.hyprland.settings = {
    bind = [
      "$mod, S, exec, ${lib.getExe screenshot}"
    ];

    windowrule = [
      "match:class com.gabm.satty, float on"
    ];
  };
}

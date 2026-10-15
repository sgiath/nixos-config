{
  lib,
  pkgs,
  ...
}:
let
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    if [[ ''${1:-} == "--monitor" ]]; then
      output="$(hyprctl -j monitors | ${lib.getExe pkgs.jq} -er '.[] | select(.focused) | .name')"
      grim_args=(-c -o "$output")
    else
      grim_args=(-g "$(${lib.getExe pkgs.slurp} -b 1B1F28CC -c E06B74ff -s C778DD0D -w 2)")
    fi

    ${lib.getExe pkgs.grim} "''${grim_args[@]}" - \
      | ${lib.getExe pkgs.satty} \
        --filename - \
        --output-filename "~/Pictures/Screenshots/%Y-%m-%dT%H%M%S.png" \
        --copy-command wl-copy \
        --floating-hack
  '';
  command = lib.getExe screenshot;
  monitorCommand = "${command} --monitor";
in
{
  home.packages = [
    screenshot
  ];

  wayland.windowManager.hyprland.settings = {
    bind = [
      {
        _args = [
          "SUPER + S"
          (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON command})")
        ];
      }
      {
        _args = [
          "SUPER + SHIFT + S"
          (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON monitorCommand})")
        ];
      }
    ];

    window_rule = [
      {
        match.class = "com.gabm.satty";
        float = true;
      }
    ];

    layer_rule = [
      # Hyprland keeps a fading snapshot of every unmapped layer (`layersOut`,
      # `fadeLayersOut` in looks.nix), so grim would capture slurp's border and
      # selection fill through it. Disabling the animation drops the snapshot.
      {
        name = "slurp-selection";
        match.namespace = "^selection$";
        no_anim = true;
      }
    ];
  };
}

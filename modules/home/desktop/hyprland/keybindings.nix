{ lib, pkgs, ... }:
let
  lua = lib.generators.mkLuaInline;
  bind = keys: dispatcher: {
    _args = [
      keys
      (lua dispatcher)
    ];
  };
  wpctl = lib.getExe' pkgs.wireplumber "wpctl";
  brightnessctl = lib.getExe pkgs.brightnessctl;
  # Media keys also work on the lock screen; volume and brightness repeat while held.
  mediaBind = keys: command: repeating: {
    _args = [
      keys
      (lua "hl.dsp.exec_cmd(${builtins.toJSON command})")
      {
        locked = true;
        inherit repeating;
      }
    ];
  };
  mouseBind = keys: dispatcher: {
    _args = [
      keys
      (lua dispatcher)
      { mouse = true; }
    ];
  };
in
{
  home.packages = with pkgs; [
    brightnessctl
    grim
    slurp
    swappy
    satty
    hyprpicker
  ];

  wayland.windowManager.hyprland.settings = {
    bind = [
      (mediaBind "XF86AudioRaiseVolume" "${wpctl} set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+" true)
      (mediaBind "XF86AudioLowerVolume" "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-" true)
      (mediaBind "XF86AudioMute" "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle" false)
      (mediaBind "XF86AudioMicMute" "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle" false)
      # The class keeps keyboard and status LEDs out of reach; desktops without a panel backlight have no target.
      (mediaBind "XF86MonBrightnessUp" "${brightnessctl} --class=backlight --min-value=1 set +5%" true)
      (mediaBind "XF86MonBrightnessDown" "${brightnessctl} --class=backlight --min-value=1 set 5%-" true)

      (bind "SUPER + SHIFT + C" "hl.dsp.window.close()")
      (bind "SUPER + F" ''hl.dsp.window.float({ action = "toggle" })'')
      (bind "SUPER + SHIFT + Space" ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })'')

      # move focus
      (bind "SUPER + H" ''hl.dsp.focus({ direction = "left" })'')
      (bind "SUPER + L" ''hl.dsp.focus({ direction = "right" })'')
      (bind "SUPER + K" ''hl.dsp.focus({ direction = "up" })'')
      (bind "SUPER + J" ''hl.dsp.focus({ direction = "down" })'')

      (bind "SUPER + left" ''hl.dsp.focus({ workspace = "r-1" })'')
      (bind "SUPER + right" ''hl.dsp.focus({ workspace = "r+1" })'')

      # go to workspace
      (bind "SUPER + grave" ''hl.dsp.workspace.toggle_special("terminal")'')
      (bind "SUPER + 1" ''hl.dsp.focus({ workspace = "1", on_current_monitor = true })'')
      (bind "SUPER + 2" ''hl.dsp.focus({ workspace = "2", on_current_monitor = true })'')
      (bind "SUPER + 3" ''hl.dsp.focus({ workspace = "3", on_current_monitor = true })'')
      (bind "SUPER + 4" ''hl.dsp.focus({ workspace = "4", on_current_monitor = true })'')
      (bind "SUPER + 5" ''hl.dsp.focus({ workspace = "5", on_current_monitor = true })'')
      (bind "SUPER + 6" ''hl.dsp.focus({ workspace = "6", on_current_monitor = true })'')
      (bind "SUPER + 7" ''hl.dsp.focus({ workspace = "7", on_current_monitor = true })'')
      (bind "SUPER + 8" ''hl.dsp.focus({ workspace = "8", on_current_monitor = true })'')
      (bind "SUPER + 9" ''hl.dsp.focus({ workspace = "9", on_current_monitor = true })'')
      (bind "SUPER + 0" ''hl.dsp.focus({ workspace = "10", on_current_monitor = true })'')

      # move to workspace
      (bind "SUPER + SHIFT + grave" ''hl.dsp.window.move({ workspace = "special:terminal" })'')
      (bind "SUPER + SHIFT + 1" ''hl.dsp.window.move({ workspace = "1" })'')
      (bind "SUPER + SHIFT + 2" ''hl.dsp.window.move({ workspace = "2" })'')
      (bind "SUPER + SHIFT + 3" ''hl.dsp.window.move({ workspace = "3" })'')
      (bind "SUPER + SHIFT + 4" ''hl.dsp.window.move({ workspace = "4" })'')
      (bind "SUPER + SHIFT + 5" ''hl.dsp.window.move({ workspace = "5" })'')
      (bind "SUPER + SHIFT + 6" ''hl.dsp.window.move({ workspace = "6" })'')
      (bind "SUPER + SHIFT + 7" ''hl.dsp.window.move({ workspace = "7" })'')
      (bind "SUPER + SHIFT + 8" ''hl.dsp.window.move({ workspace = "8" })'')
      (bind "SUPER + SHIFT + 9" ''hl.dsp.window.move({ workspace = "9" })'')
      (bind "SUPER + SHIFT + 0" ''hl.dsp.window.move({ workspace = "10" })'')

      (bind "SUPER + G" "hl.dsp.group.toggle({})")
      (bind "SUPER + SHIFT + H" ''hl.dsp.window.move({ into_group = "left" })'')
      (bind "SUPER + SHIFT + J" ''hl.dsp.window.move({ into_group = "down" })'')
      (bind "SUPER + SHIFT + K" ''hl.dsp.window.move({ into_group = "up" })'')
      (bind "SUPER + SHIFT + L" ''hl.dsp.window.move({ into_group = "right" })'')

      (mouseBind "SUPER + mouse:272" "hl.dsp.window.drag()")
      (mouseBind "SUPER + SHIFT + mouse:272" "hl.dsp.window.resize()")
    ];
  };
}

{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      # Disable blur for xwayland context menus
      "no_blur on, match:class ^()$, match:title ^()$"
      # Disable blur for all xwayland apps
      "no_blur on, match:xwayland 1"
      # Disable blur for every window
      "no_blur on, match:class .*"

      # No shadow for tiled windows (matches windows that are not floating).
      "no_shadow on, match:float 0"
    ];

    layerrule = [
      "xray 1, match:namespace .*"
      "no_anim on, match:namespace .*"
    ];
  };
}

{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      # Uncomment to apply global transparency to all windows:
      #"opacity 0.89 override 0.89 override, match:class .*"

      # Disable blur for xwayland context menus
      "no_blur on, match:class ^()$, match:title ^()$"
      # Disable blur for all xwayland apps
      #"no_blur on, match:xwayland 1"
      # Disable blur for every window
      "no_blur on, match:class .*"

      # No shadow for tiled windows (matches windows that are not floating).
      "no_shadow on, match:float 0"
    ];
  };
}

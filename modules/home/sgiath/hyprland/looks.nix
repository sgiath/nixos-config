{
  wayland.windowManager.hyprland.settings = {
    decoration = {
      rounding = 8;
      rounding_power = 2;

      active_opacity = 1.0;
      # inactive_opacity = 0.90;
      fullscreen_opacity = 1.0;

      # Dim
      dim_inactive = true;
      dim_strength = 0.025;
      dim_special = 0.07;

      blur = {
        enabled = true;
        xray = true;
        special = false;
        new_optimizations = true;
        size = 10;
        passes = 3;
        brightness = 0.5;
        noise = 0.15;
        contrast = 0.2;
        vibrancy = 0.8;
        vibrancy_darkness = 0.8;
        popups = false;
        popups_ignorealpha = 0.6;
        input_methods = true;
        input_methods_ignorealpha = 0.8;
      };

      shadow = {
        enabled = true;
        ignore_window = true;
        range = 30;
        offset = "0 2";
        render_power = 4;
        color = "rgba(00000010)";
      };

    };

    animations = {
      enabled = true;

      # Curves
      bezier = [
        "expressiveFastSpatial, 0.42, 1.67, 0.21, 0.90"
        "expressiveSlowSpatial, 0.39, 1.29, 0.35, 0.98"
        "expressiveDefaultSpatial, 0.38, 1.21, 0.22, 1.00"
        "emphasizedDecel, 0.05, 0.7, 0.1, 1"
        "emphasizedAccel, 0.3, 0, 0.8, 0.15"
        "standardDecel, 0, 0, 0, 1"
        "menu_decel, 0.1, 1, 0, 1"
        "menu_accel, 0.52, 0.03, 0.72, 0.08"
        "stall, 1, -0.1, 0.7, 0.85"
      ];

      animation = [
        # windows
        "windowsIn, 1, 3, emphasizedDecel, popin 80%"
        "fadeIn, 1, 3, emphasizedDecel"
        "windowsOut, 1, 2, emphasizedDecel, popin 90%"
        "fadeOut, 1, 2, emphasizedDecel"
        "windowsMove, 1, 3, emphasizedDecel, slide"
        "border, 1, 10, emphasizedDecel"
        # layers
        "layersIn, 1, 2.7, emphasizedDecel, popin 93%"
        "layersOut, 1, 2.4, menu_accel, popin 94%"
        # fade
        "fadeLayersIn, 1, 0.5, menu_decel"
        "fadeLayersOut, 1, 2.7, stall"
        # workspaces
        "workspaces, 1, 7, menu_decel, slide"
        ## specialWorkspace
        "specialWorkspaceIn, 1, 2.8, emphasizedDecel, slidevert"
        "specialWorkspaceOut, 1, 1.2, emphasizedAccel, slidevert"
      ];
    };
  };
}

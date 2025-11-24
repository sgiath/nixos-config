{
  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in = 4;
      gaps_out = 10;
      gaps_workspaces = 50;

      border_size = 1;
      resize_on_border = true;
      no_focus_fallback = true;
      allow_tearing = true;

      snap = {
        enabled = true;
        window_gap = 4;
        monitor_gap = 5;
        respect_gaps = true;
      };
    };

    input = {
      kb_layout = "us";
      numlock_by_default = true;
      repeat_delay = 250;
      repeat_rate = 35;

      follow_mouse = 1;
      off_window_axis_events = 2;

      touchpad = {
        natural_scroll = true;
        disable_while_typing = true;
        clickfinger_behavior = true;
        scroll_factor = 0.5;
      };
      tablet.output = "current";
    };

    misc = {
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
      vfr = 1;
      vrr = 1;
      mouse_move_enables_dpms = true;
      key_press_enables_dpms = true;
      animate_manual_resizes = false;
      animate_mouse_windowdragging = false;
      enable_swallow = false;
      swallow_regex = "(foot|kitty|allacritty|Alacritty)";
      new_window_takes_over_fullscreen = 2;
      allow_session_lock_restore = true;
      session_lock_xray = true;
      initial_workspace_tracking = false;
      focus_on_activate = true;
    };

    binds = {
      scroll_event_delay = 0;
      hide_special_on_workspace_change = true;
    };

    cursor = {
      zoom_factor = 1;
      zoom_rigid = false;
      hotspot_padding = 1;
    };
  };
}

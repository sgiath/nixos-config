{
  wayland.windowManager.hyprland.settings = {
    general.layout = "dwindle";

    dwindle = {
      force_split = 2;
      preserve_split = true;
      smart_split = true;
      split_width_multiplier = 2.0;
      default_split_ratio = 0.5;
    };

    master = {
      mfact = 0.75;
      new_status = "master";
      orientation = "center";
      slave_count_for_center_master = 1;
      center_master_fallback = "right";
      always_keep_position = true;
    };
  };
}

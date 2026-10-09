{
  wayland.windowManager.hyprland.settings = {
    monitor = [
      # Desktop
      {
        output = "DP-1";
        mode = "5120x1440@240";
        position = "0x2560";
        scale = 1;
      }
      {
        output = "DP-3";
        mode = "3440x1440@165";
        position = "0x1120";
        scale = 1;
      }
      {
        output = "DP-2";
        mode = "2560x1440@165";
        position = "3440x0";
        scale = 1;
        transform = 1;
      }

      # Notebook
      {
        output = "eDP-1";
        mode = "2560x1600@240";
        position = "0x0";
        scale = 1;
      }
    ];
  };
}

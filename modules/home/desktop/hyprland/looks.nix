let
  curve = name: points: {
    _args = [
      name
      {
        type = "bezier";
        inherit points;
      }
    ];
  };
in
{
  wayland.windowManager.hyprland.settings = {
    config = {
      decoration = {
        rounding = 8;
        rounding_power = 2;

        active_opacity = 1.0;
        # inactive_opacity = 0.80;
        fullscreen_opacity = 1.0;

        # Dim
        dim_inactive = true;
        dim_strength = 0.025;
        # Backdrop behind a shown scratchpad; the workspace stays readable under it.
        dim_special = 0.5;

        blur = {
          enabled = true;
          new_optimizations = true;
          size = 3;
          passes = 2;
          vibrancy = 0.1696;
        };

        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          # color = "rgba(1a1a1aee)";
        };
      };

      animations.enabled = true;
    };

    curve = [
      (curve "expressiveFastSpatial" [
        [
          0.42
          1.67
        ]
        [
          0.21
          0.90
        ]
      ])
      (curve "expressiveSlowSpatial" [
        [
          0.39
          1.29
        ]
        [
          0.35
          0.98
        ]
      ])
      (curve "expressiveDefaultSpatial" [
        [
          0.38
          1.21
        ]
        [
          0.22
          1.00
        ]
      ])
      (curve "emphasizedDecel" [
        [
          0.05
          0.7
        ]
        [
          0.1
          1
        ]
      ])
      (curve "emphasizedAccel" [
        [
          0.3
          0
        ]
        [
          0.8
          0.15
        ]
      ])
      (curve "standardDecel" [
        [
          0
          0
        ]
        [
          0
          1
        ]
      ])
      (curve "menu_decel" [
        [
          0.1
          1
        ]
        [
          0
          1
        ]
      ])
      (curve "menu_accel" [
        [
          0.52
          0.03
        ]
        [
          0.72
          0.08
        ]
      ])
      (curve "stall" [
        [
          1
          (-0.1)
        ]
        [
          0.7
          0.85
        ]
      ])
    ];

    animation = [
      {
        leaf = "windowsIn";
        enabled = true;
        speed = 3;
        bezier = "emphasizedDecel";
        style = "popin 80%";
      }
      {
        leaf = "fadeIn";
        enabled = true;
        speed = 3;
        bezier = "emphasizedDecel";
      }
      {
        leaf = "windowsOut";
        enabled = true;
        speed = 2;
        bezier = "emphasizedDecel";
        style = "popin 90%";
      }
      {
        leaf = "fadeOut";
        enabled = true;
        speed = 2;
        bezier = "emphasizedDecel";
      }
      {
        leaf = "windowsMove";
        enabled = true;
        speed = 3;
        bezier = "emphasizedDecel";
        style = "slide";
      }
      {
        leaf = "border";
        enabled = true;
        speed = 10;
        bezier = "emphasizedDecel";
      }
      {
        leaf = "layersIn";
        enabled = true;
        speed = 2.7;
        bezier = "emphasizedDecel";
        style = "popin 93%";
      }
      {
        leaf = "layersOut";
        enabled = true;
        speed = 2.4;
        bezier = "menu_accel";
        style = "popin 94%";
      }
      {
        leaf = "fadeLayersIn";
        enabled = true;
        speed = 0.5;
        bezier = "menu_decel";
      }
      {
        leaf = "fadeLayersOut";
        enabled = true;
        speed = 2.7;
        bezier = "stall";
      }
      {
        leaf = "workspaces";
        enabled = true;
        speed = 7;
        bezier = "menu_decel";
        style = "slide";
      }
      {
        leaf = "specialWorkspaceIn";
        enabled = true;
        speed = 2.8;
        bezier = "emphasizedDecel";
        style = "slidevert -100%";
      }
      {
        leaf = "specialWorkspaceOut";
        enabled = true;
        speed = 1.2;
        bezier = "emphasizedAccel";
        style = "slidevert -100%";
      }
    ];
  };
}

{ pkgs, ... }:
let
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.swappy}/bin/swappy -f -
  '';
in
{
  home.packages = with pkgs; [
    grim
    slurp
    swappy
    satty
    hyprpicker
  ];

  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    bind = [
      "$mod SHIFT, Q, exec, ${pkgs.wlogout}/bin/wlogout"
      "$mod, S, exec, ${screenshot}/bin/screenshot"
      "$mod, slash, exec, ${pkgs.wofi}/bin/wofi --show drun"

      "$mod SHIFT, C, killactive,"
      "$mod, R, togglesplit,"
      "$mod, F, togglefloating, active"
      "$mod SHIFT, Space, fullscreen, 0"

      # move focus
      "$mod, H, movefocus, l"
      "$mod, L, movefocus, r"
      "$mod, K, movefocus, u"
      "$mod, J, movefocus, d"

      "$mod, left, workspace, r-1"
      "$mod, right, workspace, r+1"

      # go to workspace
      "$mod, grave, togglespecialworkspace, special:nasa"
      "$mod, 1, focusworkspaceoncurrentmonitor, 1"
      "$mod, 2, focusworkspaceoncurrentmonitor, 2"
      "$mod, 3, focusworkspaceoncurrentmonitor, 3"
      "$mod, 4, focusworkspaceoncurrentmonitor, 4"
      "$mod, 5, focusworkspaceoncurrentmonitor, 5"
      "$mod, 6, focusworkspaceoncurrentmonitor, 6"
      "$mod, 7, focusworkspaceoncurrentmonitor, 7"
      "$mod, 8, focusworkspaceoncurrentmonitor, 8"
      "$mod, 9, focusworkspaceoncurrentmonitor, 9"
      "$mod, 0, focusworkspaceoncurrentmonitor, 10"

      # move to workspace
      "$mod SHIFT, grave, movetoworkspace, special:nasa"
      "$mod SHIFT, 1, movetoworkspace, 1"
      "$mod SHIFT, 2, movetoworkspace, 2"
      "$mod SHIFT, 3, movetoworkspace, 3"
      "$mod SHIFT, 4, movetoworkspace, 4"
      "$mod SHIFT, 5, movetoworkspace, 5"
      "$mod SHIFT, 6, movetoworkspace, 6"
      "$mod SHIFT, 7, movetoworkspace, 7"
      "$mod SHIFT, 8, movetoworkspace, 8"
      "$mod SHIFT, 9, movetoworkspace, 9"
      "$mod SHIFT, 0, movetoworkspace, 10"

      "$mod, G, togglegroup,"
      "$mod SHIFT, H, moveintogroup, l"
      "$mod SHIFT, J, moveintogroup, d"
      "$mod SHIFT, K, moveintogroup, u"
      "$mod SHIFT, L, moveintogroup, r"
    ];

    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod SHIFT, mouse:272, resizewindow"
    ];
  };
}

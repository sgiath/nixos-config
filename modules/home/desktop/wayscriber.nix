{
  config,
  lib,
  pkgs,
  ...
}:
let
  wayscriber = lib.getExe pkgs.wayscriber;
  exec = command: lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON command})";
in
{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    home.packages = [ pkgs.wayscriber ];

    # Daemon holds the annotation overlay hidden until toggled; the
    # package ships no unit, so define one tied to the Wayland session.
    systemd.user.services.wayscriber = {
      Unit = {
        Description = "Wayscriber screen annotation daemon";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
      };
      Service = {
        ExecStart = "${wayscriber} --daemon";
        Restart = "on-failure";
        Slice = "app.slice";
      };
      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    wayland.windowManager.hyprland.settings.bind = [
      {
        _args = [
          "SUPER + A"
          (exec "${wayscriber} --daemon-toggle")
        ];
      }
      {
        _args = [
          "SUPER + SHIFT + A"
          (exec "${wayscriber} --daemon-toggle --freeze")
        ];
      }
    ];
  };
}

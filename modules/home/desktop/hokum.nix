{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  hokum = pkgs.${namespace}.hokum;

  # Hokum saves its settings window and `hokum dnd` into config.kdl by
  # replacing the file, so the file belongs to Hokum: seeded once, never
  # managed. Changing this seed does not touch an existing config.
  seed = pkgs.writeText "hokum-config.kdl" ''
    // Seeded by Home Manager on first activation; Hokum edits it from here on.
    behaviour {
        check-for-updates #false
    }
  '';
in
{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    home.packages = [ hokum ];

    # Lets the bus start the unit if a notification arrives while it is down.
    xdg.dataFile."dbus-1/services/app.hokum.Notifications.service".source =
      "${hokum}/share/dbus-1/services/app.hokum.Notifications.service";

    systemd.user.services.hokum = {
      Unit = {
        Description = "Hokum notification daemon";
        Documentation = [ "https://hokum.app" ];
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
      };
      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecStart = "${lib.getExe hokum} service";
        Restart = "on-failure";
        # 78: no layer-shell, or another shell keeps the notification name.
        RestartPreventExitStatus = 78;
        RestartSec = 2;
      };
      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    home.activation.seedHokumConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      hokumConfig=${lib.escapeShellArg "${config.xdg.configHome}/hokum/config.kdl"}
      if [[ ! -e $hokumConfig && ! -L $hokumConfig ]]; then
        run mkdir -p "$(dirname "$hokumConfig")"
        run install -m 644 ${seed} "$hokumConfig"
      fi
    '';
  };
}

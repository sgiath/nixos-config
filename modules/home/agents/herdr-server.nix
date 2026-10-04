{
  config,
  lib,
  pkgs,
  apiKeyWrapper,
  ...
}:
let
  cfg = config.services.herdr-server;
  graphical = config.sgiath.roles.desktop.enable;
  rawHerdr = lib.getExe pkgs.herdr;
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  socketDir = "${config.xdg.configHome}/herdr";

  # The remote web bridge discovers this installed command and invokes
  # `herdr server`. Both it and a local client use the same managed daemon.
  launcher = pkgs.writeShellScript "herdr-managed" ''
    set -euo pipefail
    if [[ $# == 0 || ( $# == 1 && "$1" == server ) ]]; then
      if ! ${systemctl} --user start herdr-server.service; then
        echo "herdr: could not start herdr-server.service; inspect journalctl --user -u herdr-server" >&2
        ${lib.optionalString graphical ''
          echo "herdr: the desktop daemon requires an active graphical login" >&2
        ''}
        exit 1
      fi
      if [[ $# == 1 ]]; then
        exit 0
      fi
    fi
    exec ${rawHerdr} "$@"
  '';

  managedHerdr = pkgs.symlinkJoin {
    name = "herdr-managed-${pkgs.herdr.version}";
    paths = [ pkgs.herdr ];
    postBuild = ''
      rm $out/bin/herdr
      ln -s ${launcher} $out/bin/herdr
    '';
    meta = pkgs.herdr.meta;
  };

  ready = pkgs.writeShellScript "herdr-server-ready" ''
    set -euo pipefail
    for ((attempt = 0; attempt < 200; attempt++)); do
      if [[ -S ${lib.escapeShellArg "${socketDir}/herdr.sock"} && -S ${lib.escapeShellArg "${socketDir}/herdr-client.sock"} ]] &&
        ${rawHerdr} status server --json 2>/dev/null |
          ${lib.getExe pkgs.jq} -e '.running == true' >/dev/null; then
        exit 0
      fi
      ${lib.getExe' pkgs.coreutils "sleep"} 0.05
    done
    echo "herdr: server did not become ready; inspect journalctl --user -u herdr-server" >&2
    exit 1
  '';

  displayCheck = pkgs.writeShellScript "herdr-server-display" ''
    if [[ -z "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" ]]; then
      echo "herdr: graphical session has not imported its display environment" >&2
      exit 1
    fi
  '';

  ownershipCheck = pkgs.writeShellScript "herdr-server-ownership" ''
    set -euo pipefail
    if ${rawHerdr} status server --json 2>/dev/null |
      ${lib.getExe pkgs.jq} -e '.running == true' >/dev/null; then
      echo "herdr: an unmanaged daemon is already running; finish its panes and stop it before starting herdr-server.service" >&2
      exit 1
    fi
  '';
in
{
  options.services.herdr-server.enable = lib.mkEnableOption "managed default Herdr daemon";

  config = lib.mkIf cfg.enable {
    programs.herdr.package = managedHerdr;

    systemd.user.services.herdr-server = {
      Unit = {
        Description = "Herdr default session";
        After = if graphical then [ "graphical-session.target" ] else [ "network-online.target" ];
        Wants = lib.optional (!graphical) "network-online.target";
        Requisite = lib.optional graphical "graphical-session.target";
        # Session logout also invalidates the daemon's display environment.
        PartOf = lib.optional graphical "graphical-session.target";
        # A rebuild must not terminate panes or agents.
        X-SwitchMethod = "keep-old";
      };

      Service = {
        Type = "exec";
        ExecStartPre = lib.optional graphical "${displayCheck}" ++ [ "${ownershipCheck}" ];
        ExecStart = "${lib.getExe apiKeyWrapper} ${rawHerdr} server";
        ExecStartPost = "${ready}";
        WorkingDirectory = config.home.homeDirectory;
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "PATH=/run/wrappers/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
          "SHELL=${lib.getExe pkgs.zsh}"
          "SSH_AUTH_SOCK=%t/gnupg/S.gpg-agent.ssh"
        ];
        UnsetEnvironment = [
          "SSH_CONNECTION"
          "SSH_CLIENT"
          "SSH_TTY"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = 15;
      };

      Install.WantedBy = [ (if graphical then "graphical-session.target" else "default.target") ];
    };

    # The login terminal must not auto-spawn a daemon before the managed one
    # has finished restoring its session and opening both sockets.
    systemd.user.services.kitty = lib.mkIf graphical {
      Unit = {
        After = [ "herdr-server.service" ];
        Requires = [ "herdr-server.service" ];
      };
    };
  };
}

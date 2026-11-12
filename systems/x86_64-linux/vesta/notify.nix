# `OnFailure = [ "notify-failure@%n.service" ]` posts the unit's last log lines
# to the `infra` topic of the local ntfy server (ntfy.sgiath.dev).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  url = "http://127.0.0.1${config.services.ntfy-sh.settings.listen-http}/infra";
in
{
  systemd.services."notify-failure@" = {
    description = "Report the failure of %i to ntfy";
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "1min";
    };
    scriptArgs = "%i";
    path = [
      pkgs.curl
      pkgs.systemd
    ];
    script = ''
      journalctl --unit "$1" --lines 20 --no-pager --output cat \
        | curl --fail --silent --show-error --max-time 30 \
          --header "Title: $1 failed on ${config.networking.hostName}" \
          --header "Priority: high" --data-binary @- ${lib.escapeShellArg url}
    '';
  };
}

# Oracle may stop Hygiea's Always Free VM when it looks idle for a week, and a
# backup lighthouse looks idle almost always. Every 15 minutes Vesta pings
# Hygiea over Nebula; when it does not answer and Oracle reports the instance
# STOPPED, it starts it through the OCI API. Changes of state go to the `infra`
# ntfy topic; a failed start fails the unit, which reports through
# notify-failure@.
#
# OCI side: user hygiea-watchdog in group HygieaRestarter, allowed to read
# instances and run instance actions only in compartment `hygiea`, which holds
# just this instance. Oracle has no start-only permission, so a leaked key
# could also stop or reset Hygiea, but not delete or create anything. The
# API key is `hygiea_oci_key` in secrets/vesta.yaml; its public half is
# uploaded to the user (fingerprint below).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  hygiea = config.sgiath.nebula.peers.hygiea;
  ntfy = "http://127.0.0.1${config.services.ntfy-sh.settings.listen-http}/infra";
  oci = {
    tenancy = "ocid1.tenancy.oc1..aaaaaaaa4c3s36j5tax5w6fst2mxwmdfdze7j4ranfml33jgni4mm3dhc3ta";
    user = "ocid1.user.oc1..aaaaaaaa6osuqtw5gck6mgpx73olucrr4ovsw4u3snloecvgusayffdwrhca";
    fingerprint = "38:a4:86:ac:6c:00:c0:f3:50:14:0b:7a:9d:44:f7:82";
    region = "eu-frankfurt-1";
    instance = "ocid1.instance.oc1.eu-frankfurt-1.antheljrjrpndxicvmjk4obcs4r5xljjuy6ffbdu3ypikc4rc4le3srykzsa";
  };
  ociConfig = pkgs.writeText "oci-config" ''
    [DEFAULT]
    user=${oci.user}
    fingerprint=${oci.fingerprint}
    tenancy=${oci.tenancy}
    region=${oci.region}
    key_file=/run/credentials/hygiea-watchdog.service/oci-key
  '';

  watchdog = pkgs.writeShellApplication {
    name = "hygiea-watchdog";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.iputils
      pkgs.oci-cli
    ];
    text = ''
      state="$STATE_DIRECTORY/last"
      previous="$(cat "$state" 2>/dev/null || echo ok)"

      notify() {
        curl --fail --silent --show-error --max-time 30 --header "Title: Hygiea" \
          --data-binary "$1" ${lib.escapeShellArg ntfy} >/dev/null || true
      }
      # Notify only when the observed state changes.
      record() {
        if [[ "$1" != "$previous" ]]; then
          notify "$2"
        fi
        printf '%s\n' "$1" >"$state"
      }
      oci_cli() {
        oci --config-file ${ociConfig} --connection-timeout 10 --read-timeout 30 --max-retries 2 "$@"
      }

      if ping -c 3 -W 5 ${hygiea.ip4} >/dev/null; then
        record ok "Hygiea answers over Nebula again"
        exit 0
      fi

      lifecycle="$(oci_cli compute instance get --instance-id ${oci.instance} \
        --query 'data."lifecycle-state"' --raw-output)"
      if [[ "$lifecycle" == STOPPED ]]; then
        notify "Oracle stopped Hygiea; starting it"
        oci_cli compute instance action --instance-id ${oci.instance} --action START \
          --wait-for-state RUNNING --max-wait-seconds 600 --wait-interval-seconds 15 >/dev/null
        record started "Hygiea is running again; waiting for Nebula"
      else
        record "$lifecycle" "Hygiea does not answer over Nebula; Oracle reports it $lifecycle"
      fi
    '';
  };
in
{
  sops.secrets.hygiea_oci_key.sopsFile = ../../../secrets/vesta.yaml;

  systemd.services.hygiea-watchdog = {
    description = "Start Hygiea when Oracle stopped it";
    after = [ "nebula@sgiath.service" ];
    onFailure = [ "notify-failure@%n.service" ];
    environment.OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING = "True";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe watchdog;
      DynamicUser = true;
      StateDirectory = "hygiea-watchdog";
      LoadCredential = [ "oci-key:${config.sops.secrets.hygiea_oci_key.path}" ];
      AmbientCapabilities = [ "CAP_NET_RAW" ];
      CapabilityBoundingSet = [ "CAP_NET_RAW" ];
      TimeoutStartSec = "15min";
    };
  };

  systemd.timers.hygiea-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";
      RandomizedDelaySec = "2min";
    };
  };
}

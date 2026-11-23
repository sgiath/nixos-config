# Monthly scrub of the root filesystem, run only at night. Ceres is often off
# at night, so the timer tries every night at 01:00 and the service skips
# itself while the last scrub finished less than 28 days ago. The upstream
# timer is Persistent with a one-day accuracy, which would start a missed
# scrub at boot or in the afternoon; both are turned off here. A timer that
# elapsed during suspend fires on resume, so the service also refuses to
# start outside 01:00-01:59 UTC, and RuntimeMaxSec ends it by 07:00.
{ lib, pkgs, ... }:
let
  scrubDue = pkgs.writeShellApplication {
    name = "btrfs-scrub-due";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    # ExecCondition: 0 runs the scrub, 1 skips it, 255 fails the unit.
    text = ''
      hour="$(date -u +%H)"
      if [[ "$hour" != 01 ]]; then
        echo "it is $hour:xx UTC, outside the 01:00-01:59 start window; skipping"
        exit 1
      fi
      if ! out="$(btrfs scrub status "$1")"; then
        echo "btrfs scrub status $1 failed" >&2
        exit 255
      fi
      if grep -q 'no stats available' <<< "$out"; then
        echo "no scrub recorded; scrubbing"
        exit 0
      fi
      status="$(sed -n 's/^Status: *//p' <<< "$out")"
      started="$(sed -nE 's/^Scrub (started|resumed): *//p' <<< "$out")"
      case "$status" in
        finished) ;;
        interrupted | aborted)
          echo "last scrub $status; scrubbing"
          exit 0
          ;;
        running)
          echo "a scrub is already running; skipping"
          exit 1
          ;;
        *)
          echo "unexpected btrfs scrub status output:" >&2
          echo "$out" >&2
          exit 255
          ;;
      esac
      if [[ -z "$started" ]] || ! started_s="$(date -d "$started" +%s)"; then
        echo "cannot parse the last scrub's start time '$started'" >&2
        exit 255
      fi
      age_days=$((($(date +%s) - started_s) / 86400))
      if ((age_days < 28)); then
        echo "last scrub finished, started $age_days days ago; skipping"
        exit 1
      fi
      echo "last scrub started $age_days days ago; scrubbing"
    '';
  };
in
{
  # The NVMe scheduler is "none", so the unit's idle IO class has no effect.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "*-*-* 01:00:00";
    fileSystems = [ "/" ];
    limit = "500M";
  };

  systemd = {
    timers."btrfs-scrub@".timerConfig = {
      AccuracySec = lib.mkForce "1min";
      Persistent = lib.mkForce false;
    };

    services."btrfs-scrub@".serviceConfig = {
      ExecCondition = "${lib.getExe scrubDue} %f";
      # 1.8 TiB at 500 MB/s takes about an hour; a start at 01:59 is stopped
      # (ExecStop cancels the scrub) by 06:59.
      RuntimeMaxSec = "5h";
    };
  };
}

# The Blade 14 (2023) speaker amplifier stays silent until its ALC298 codec
# (10ec:0298, subsystem 1a58:2020) receives a vendor coefficient sequence that
# Linux has no quirk for. The sequence comes from
# https://github.com/yadu-tv/rb14-2023-audio-fix and is replayed after the
# kernel's codec init (at boot and after resume); the kernel's own patch loader
# applies verbs before that init, which can overwrite them.
{ pkgs, ... }:
let
  source = pkgs.fetchFromGitHub {
    owner = "yadu-tv";
    repo = "rb14-2023-audio-fix";
    rev = "e3d9b20535afe5f6892a024d8afa71be2239a47b";
    hash = "sha256-FdiS4JOa+qWcatHE0LSyTEe2cGU3/254qBBqiV3pHUQ=";
  };
  ids = ''ATTR{vendor_id}=="0x10ec0298", ATTR{subsystem_id}=="0x1a582020"'';
  initialize = pkgs.writeShellScript "pallas-speaker-init" ''
    set -eu
    target=""
    for codec in /sys/class/sound/hwC*D*; do
      [[ -r $codec/vendor_id ]] || continue
      if [[ $(<"$codec/vendor_id") == 0x10ec0298 && $(<"$codec/subsystem_id") == 0x1a582020 ]]; then
        target="/dev/snd/''${codec##*/}"
      fi
    done
    if [[ -z $target ]]; then
      echo "ALC298 codec 10ec:0298 / 1a58:2020 not found" >&2
      exit 1
    fi
    count=0
    while read -r command _device nid verb value; do
      [[ $command == hda-verb ]] || continue
      count=$((count + 1))
      ${pkgs.alsa-tools}/bin/hda-verb "$target" "$nid" "$verb" "$value" >/dev/null
    done < ${source}/rb_audio.sh
    echo "Initialized the speaker amplifier through $target ($count verbs)"
  '';
in
{
  # FIXME: Drop this when the kernel carries a quirk for SSID 1a58:2020.
  services.udev.extraRules = ''
    SUBSYSTEM=="sound", KERNEL=="hwC*D*", ${ids}, TAG+="systemd", ENV{SYSTEMD_WANTS}+="pallas-speaker-init.service"
    # A runtime-suspended codec is re-initialized on wake and loses the sequence.
    SUBSYSTEM=="hdaudio", ${ids}, ATTR{power/control}="on"
  '';

  systemd.services.pallas-speaker-init = {
    description = "Initialize the Razer Blade 14 speaker amplifier";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = initialize;
      TimeoutStartSec = 60;
    };
  };

  powerManagement.resumeCommands = "${pkgs.coreutils}/bin/timeout 60s ${initialize}";
}

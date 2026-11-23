# Fan curve for the RX 6950 XT. Under load the stock curve let the hotspot
# reach 94 C at 319 W, 1 C below the card's 95 C critical limit; this curve
# follows the hotspot (junction) and reaches full speed at 92 C.
#
# LACT keys a GPU by its PCI IDs and slot (`1002:73A5-1DA2:D440-0000:3f:00.0`),
# and Ceres's GPU bus number moves when PCIe devices or BIOS settings change
# (0000:41 before 2026-11-20, 0000:3f since). The config is therefore written
# at every daemon start with the slot the amdgpu driver is bound to.
{ lib, pkgs, ... }:
let
  # A hand-written template: LACT parses curve keys as integers, and a YAML
  # generator would quote them as strings.
  template = pkgs.writeText "lact-config.yaml" ''
    version: 7
    daemon:
      log_level: info
      admin_group: wheel
      disable_clocks_cleanup: false
    apply_settings_timer: 5
    gpus:
      '@GPU_ID@':
        fan_control_enabled: true
        fan_control_settings:
          mode: curve
          static_speed: 0.5
          temperature_key: junction
          interval_ms: 500
          curve:
            50: 0.3
            65: 0.4
            75: 0.55
            85: 0.8
            92: 1.0
          spindown_delay_ms: 5000
          change_threshold: 2
  '';

  writeConfig = pkgs.writeShellApplication {
    name = "lact-write-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      devices=(/sys/bus/pci/drivers/amdgpu/0000:*)
      if [[ ''${#devices[@]} -ne 1 || ! -e "''${devices[0]}" ]]; then
        echo "expected exactly one device bound to amdgpu, found: ''${devices[*]}" >&2
        exit 1
      fi
      id="" subsys="" slot=""
      while IFS='=' read -r key value; do
        case "$key" in
          PCI_ID) id="$value" ;;
          PCI_SUBSYS_ID) subsys="$value" ;;
          PCI_SLOT_NAME) slot="$value" ;;
        esac
      done < "''${devices[0]}/uevent"
      if [[ "$id" != "1002:73A5" || "$subsys" != "1DA2:D440" ]]; then
        echo "amdgpu device $slot is $id/$subsys, not the RX 6950 XT (1002:73A5/1DA2:D440) this curve is for" >&2
        exit 1
      fi
      sed "s|@GPU_ID@|$id-$subsys-$slot|" ${template} > "$RUNTIME_DIRECTORY/config.yaml"
    '';
  };
in
{
  services.lact.enable = true;

  systemd.services.lactd = {
    restartTriggers = [ template ];
    environment.LACT_DAEMON_CONFIG_DIR = "/run/lact";
    serviceConfig = {
      RuntimeDirectory = "lact";
      ExecStartPre = lib.getExe writeConfig;
    };
  };
}

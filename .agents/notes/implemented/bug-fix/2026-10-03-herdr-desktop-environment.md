# Agent Note: manage Herdr's desktop environment before clients attach

Status: implemented

## Problem

After Ceres rebooted, Vesta's remote web bridge started the default Herdr
daemon through SSH before the local terminal attached. All panes inherited
that SSH environment: no `DISPLAY` or `WAYLAND_DISPLAY`, and SSH markers
that made Starship display its remote-session modules. `xdg-open` selected
the installed terminal browser and Zed ran headlessly without showing a
window. The graphical session's environment was correct.

## Decision

`modules/home/agents/herdr-server.nix` owns a separately enabled default
daemon. Ceres enables it in its home configuration; the web service enables
it on Vesta. Ceres's daemon starts after `graphical-session.target`, requires
that target and a display environment, and strips `SSH_CONNECTION`,
`SSH_CLIENT`, and `SSH_TTY` while retaining the SSH agent socket. Readiness
checks both socket paths and the daemon's live status before clients start.
Startup refuses to replace an existing unmanaged daemon, preserving its
panes during the first deployment.

The installed Herdr command routes bare local startup and `herdr server`
through `systemctl --user start herdr-server.service`. The remote bridge
already discovers that installed command, so no downloaded runtime is
patched and future bridge updates keep using the managed daemon. Other
commands, including explicit named sessions, retain upstream behavior. The
service itself invokes the original binary to avoid recursive startup.

The login terminal requires the ready daemon. A desktop daemon follows the
graphical session's lifetime, so logging out stops its panes and agents and
the next login receives a fresh display environment. Vesta remains headless
and retains its daemon across SSH disconnects and logout. Rebuilds keep an
existing daemon running via `X-SwitchMethod = keep-old`.

## Verification

Full NixOS builds passed for Ceres and Vesta. Isolated checks passed for
launcher routing, failed startup without graphical login, display checks,
socket readiness, SSH marker removal, unmanaged daemon protection, and
graphical logout stopping the daemon.

Ceres generation 1610 was installed with `nixos-rebuild boot`, leaving the
running generation and unmanaged daemon unchanged. The next reboot activates
the fix; finish the current panes and agents before rebooting.

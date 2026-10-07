# Agent Note: adopt T3 Code's child input pipe error fix

Status: proposed

## Problem

On Ceres, T3 Code `0.0.46-nightly.20261007.2761` displays
“ceres is reconnecting” while editing settings. The desktop renderer's
`server.updateSettings` request starts at 16:15:08 UTC and fails after
14.25 seconds with `SocketReadError`. Descriptor requests to its embedded
backend, `127.0.0.1:3774`, then time out. At 16:15:45 the desktop records
that backend's exit with code 1 and an unhandled `read ECONNRESET` from
`Pipe.onStreamRead` on a `Socket`. It reconnects to a replacement backend
at 16:15:50. The failed child output is saved in
`~/.t3/userdata/logs/server-child.log`.

The Nix-managed user service remains running on `10.42.0.6:3773` without
an automatic restart. `/proc/<pid>/fd` confirms that both backends open
the same `~/.t3/userdata/statev2.sqlite` and WAL. This duplicate ownership
is independently covered by [upstream issue #6097](https://github.com/pingdotgg/t3code/issues/6097).
It does not establish the cause of the pipe reset.

[Upstream PR #16555](https://github.com/pingdotgg/t3code/pull/16555)
addresses the exact pipe crash signature. Effect's child process spawner
only observes input pipe errors while its sink writes; a late error after
the writer is interrupted can terminate the server. The PR adds permanent
error listeners to stdin and extra input descriptors. Its regression
cases reproduce queued-input teardown failures on both stdin and fd 3.
[Issue #16794](https://github.com/pingdotgg/t3code/issues/16794) reports the
same failure on a headless server, including a repeat on Ceres's pinned
version. PR #16555 is open as of 2026-10-07.

The local logs identify the crash and recovery, but not which child pipe
reset or whether the settings edit triggered it. There is no local
deterministic reproduction of the settings scenario yet.

## Proposal

Adopt a coordinated CLI/desktop nightly containing #16555 when available,
through [the existing nightly updater](../../../../packages/t3code-nightly/update.sh).
Verify the release's source actually includes the fix rather than assuming
a newer version fixes it. If crashes require an earlier backport, first
reproduce input-pipe teardown against the packaged runtime and preserve
the upstream regression contract; avoid a global uncaught-exception handler.

Keep one backend per T3 data directory. On service-managed desktop hosts,
use the desktop's `localEnvironmentEnabled = false` preference and a
paired direct connection to the existing service. Preserve background
availability and the service's Nebula-only binding. The setting and
connection live in mutable desktop state, not in Nix's package version pin.

## Acceptance criteria

- CLI and desktop pins include the upstream input pipe listeners.
- Killing a child with queued stdin or fd 3 input does not kill the server;
  an active write error still fails its operation.
- A settings-edit session remains connected under comparable conditions.
  Record repeated attempts; a successful descriptor probe is not evidence
  that the intermittent crash is fixed.
- After a desktop relaunch, only the background service owns Ceres's
  database, and the desktop can read threads and operate a browser preview.
- Remote access remains available when the desktop is closed.

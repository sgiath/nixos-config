# Agent Note: herdr web UI on every host, reachable from the phone

Status: implemented

## Problem

Agent threads live in herdr panes on several machines. The main workflow is
omp, where an Opus thread natively spawns gpt-6.1-sol subagents. To see and
answer threads, sgiath had to switch herdr tabs on whichever machine ran
them. There was no single inbox, and no way to follow threads from the phone.

T3 Code (`services.t3code`, on vesta/ceres/pallas over Nebula) solves the
multi-machine and phone part, but it replaces omp's own orchestration, so it
is not used for real work.

Inspiration: Theo's "token-maxing" setup (youtu.be/D8PikZ1KhUo): agents run
on always-on boxes and laptops are only clients; one sidebar covers every
machine; threads are an inbox (look only at done/input, settle finished
threads, one worktree per thread).

## Decision

One herdr-web-ui server on vesta is the only web endpoint. Ceres and the
Remote MacBook join its sidebar as remote PCs over SSH, so there is one
origin, one PWA, one push subscription and one "Needs you" list.

1. **Package.** `packages/herdr-web-ui` builds github:devswha/herdr-web-ui
   (MIT, Bun/React) from a `vX.Y.Z` tag. `bun install --frozen-lockfile
   --ignore-scripts` runs in a fixed-output `node_modules` derivation
   (`passthru.node_modules`); Vite builds `dist/` at package time;
   autoPatchelf fixes the `@lydell/node-pty` prebuilt. Bun installs only the
   build platform's optional prebuilts, so the package is x86_64-linux only.
   `bin/herdr-web-ui` runs `bun server/index.ts` with `nodejs` (PTY sidecar),
   `herdr`, `openssh` and `git` on PATH. `update.sh` picks the newest `v*`
   tag (ignoring the bridge bundle's `remote-v*` tags) and is run by
   `scripts/update-inputs.sh`.
2. **No herdr plugin system.** `herdr plugin link` writes herdr's plugin
   registry imperatively, and the plugin's startup command runs
   `server/managed.ts`, which polls GitHub releases and installs updates at
   runtime. `server/index.ts` is the unmanaged entry point: no release
   polling, and the update API answers 409 `updates_unmanaged`.
3. **User services on vesta.** NixOS `services.herdr-web.enable`
   (`modules/nixos/services/herdr-web.nix`, enabled in vesta's
   `services.nix`) sets HM `services.herdr-web`
   (`modules/home/agents/herdr-web.nix`), which enables the independently
   defined `services.herdr-server` (`modules/home/agents/herdr-server.nix`):
   - `herdr-server.service` runs `herdr server` on the default socket under
     `with-api-keys`, with `HOME`, the profile `PATH`, `SHELL` (zsh) and the
     gpg-agent `SSH_AUTH_SOCK`; panes inherit that environment. `herdr` over
     SSH attaches to the same session; lingering keeps it across logout.
     `X-SwitchMethod = keep-old` keeps a switch from restarting it, because
     stopping it kills every agent in its cgroup.
   - `herdr-web.service` runs the package after `herdr-server.service` with
     `Restart=always`, `HOST=127.0.0.1`, `PORT=7317`,
     `HERDR_WEB_STATE_DIR=~/.config/herdr-web-ui` (paired devices, PC roster,
     `vapid.json`) and `HERDR_WEB_TOKEN` from a SOPS template
     (`herdr-web-token` in `secrets/vesta.yaml`).
4. **Overlay only.** `herdr` is in `sgiath.nebula.services`;
   `herdr.sgiath.dev` is an nginx vhost with ACME DNS-01, overlay-only
   `allow`/`deny`, websocket proxying, `proxy_buffering off`, 1 h timeouts and
   a 16 MiB body limit for pasted images. nginx injects `Authorization: Bearer
   <token>` from the systemd credential, as for T3 Code, so Nebula membership
   is the login. The server identifies proxied requests by `Host` and
   `X-Forwarded-*`, which the global `recommendedProxySettings` sends.
5. **Ceres as a remote PC.** Vesta holds a dedicated ed25519 key per PC in
   `secrets/vesta.yaml` (`herdr-web-<pc>-ssh-key`, readable by sgiath at
   `/run/secrets/`); the public halves are `secrets/herdr-web-<pc>.pub`.
   Ceres authorizes its key with `from=` vesta's overlay addresses,
   `restrict,port-forwarding,permitopen="127.0.0.1:*"`. The server installs an
   upstream prebuilt, checksum-verified bridge bundle on the PC (version fixed
   by the pinned release's `REMOTE_BUNDLE_VERSION`), which runs on NixOS via
   `programs.nix-ld`, and forwards its loopback port.
   Ceres's default daemon is now managed independently of the web service;
   [desktop daemon startup](../bug-fix/2026-10-03-herdr-desktop-environment.md)
   prevents the SSH bridge from supplying a headless environment to local panes.
6. **One worktree per thread.** `herdr-thread <branch> <prompt>`
   (`modules/home/agents/herdr-thread.{nix,sh}`) creates the branch and
   worktree with `wt switch --create` (pre-start hooks run, the herdr
   post-switch hook is skipped), opens it with `herdr worktree open` from the
   main checkout's workspace, then runs `herdr agent start --kind omp` and
   `herdr agent prompt`, the sequence `system-failure-watcher.sh` uses.
7. **The Remote MacBook is a `remote` Nebula peer.** The peers table entry
   `mac` (10.42.0.21) carries `remote = true`; its certificate is signed with
   group `remote`. NixOS Nebula inbound is an allowlist of non-`remote` peers
   by certificate name, so the Mac gets no inbound port on any NixOS host,
   while vesta's outbound SSH to it works. `scripts/nebula-remote.sh`
   renders the Mac's nebula daemon config, whose inbound allows only TCP 22
   from vesta. The Mac's SSH key is `herdr-web-mac-ssh-key`. Agent runs for
   Remote repos happen on the Mac only, under the company accounts logged in
   there; the flake knows the Mac only as a Nebula address, a certificate
   and a public key.

## Alternatives considered

- **One web server and vhost per host** (`herdr-ceres`, `herdr-mac`): no SSH
  key on vesta into other hosts, but each origin is a separate PWA with its
  own push subscription and no shared "Needs you" list. Kept only as the Mac
  fallback if Remote Login cannot be enabled: the Mac runs its own
  herdr-web-ui on its Nebula address with its own token, vesta proxies a
  `herdr-mac` vhost to it, and the Mac's Nebula rules allow that port from
  vesta only.
- **herdr plugin install or link**: the supported upstream path, but
  imperative, tied to herdr's lifetime instead of systemd, and runs the
  self-updating supervisor.
- **T3 Code everywhere**: the best multi-host and phone UX, with built-in
  settle and worktrees, but it loses omp's native subagent orchestration.
  Its removal is tracked in
  [decide T3 Code's fate](../../proposed/simplification/2026-10-02-t3code-after-herdr-web-trial.md).
- **Tailscale + `tailscale serve`** (upstream default): redundant with
  Nebula.
- **A public vhost**: the UI is effectively a shell on the host.
- **SSH + herdr from a phone terminal**: no notifications and no chat view.
- **Allowing the Mac by group rules**: Nebula rules cannot exclude a group,
  so the allowlist is derived from the peers table instead.

## Consequences

- A herdr bump on vesta takes effect only after
  `systemctl --user restart herdr-server`, which kills running agents. A
  rotated web token takes effect after restarting `herdr-web.service`.
- Losing `~/.config/herdr-web-ui/vapid.json` on vesta breaks every push
  subscription.
- Settings → Updates reports updates as unmanaged; versions move only through
  `packages/herdr-web-ui/update.sh`. Upstream releases nearly daily, so
  expect frequent hash updates and breaking changes.
- "Update PC bridges automatically" must stay off; after a bump that raises
  the bridge bundle version, press "Update bridge" once per PC. Bridge
  runtimes are upstream binaries Nix does not build.
- A compromised vesta gets a shell on ceres and the Mac through the bridge
  keys. Any compromised personal peer, including the phone, gets a shell on
  vesta through the UI, since the token is injected for every overlay client.
- Remote transcripts, file previews and terminal output pass through vesta's
  server in memory, and `machines.json` on vesta stores roster snapshots
  (workspace and pane names, working directories, status). Keeping Remote
  data off personal hosts entirely would need the phone to reach the Mac
  directly, with its own TLS certificate and a second PWA.
- Push notification text passes through the phone vendor's push service,
  end-to-end encrypted; pushes arrive while the tunnel is down, opening one
  needs Nebula.
- Ceres is a daytime worker: while it is off, the sidebar keeps its last
  roster with controls disabled. Remote threads pause when the Mac sleeps.
- Operational follow-ups, not code: deploy vesta and ceres; add ceres and
  the Mac with **Add PC** and turn off automatic bridge updates; set up the
  Mac (nebula config from `scripts/nebula-remote.sh mac`, Remote Login, the
  authorized key from `secrets/herdr-web-mac.pub`); install the PWA on the
  phone and enable alerts; remove or keep agent-free any Remote checkout on
  ceres (`~/develop/remote`). The README section "Agent threads in the
  browser" lists the steps.
- Verification after deploy: `herdr.sgiath.dev` loads from personal Nebula
  peers and is refused from the LAN, the public IP and the `mac` peer; port
  7317 answers only on loopback; vesta's omp panes show transcripts in chat
  view; ceres's panes join the sidebar; the phone gets a push when a pane
  needs input or finishes; `herdr-server` survives logout and a switch; `ps`
  shows Remote agents only on the Mac; no port on vesta or ceres answers the
  Mac over Nebula.
- Inbox hygiene and omp subagent transcripts are upstream work, tracked in
  [herdr web UI inbox hygiene and OMP subagent transcripts](../../proposed/feature/2026-10-02-herdr-web-inbox-and-subagents.md).

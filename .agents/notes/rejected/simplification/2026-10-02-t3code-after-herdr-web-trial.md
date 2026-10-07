# Agent Note: decide T3 Code's fate after the herdr web UI trial

Status: rejected - herdr web UI removed; T3 Code remains configured

## Problem

T3 Code (`services.t3code`, `modules/home/agents/t3code.nix`) runs on Vesta,
Ceres and Pallas and is exposed as `t3.sgiath.dev` and `t3-ceres.sgiath.dev`
over Nebula. It was the only way to follow agent threads from the phone, but
it replaces OMP's own orchestration, so it is not used for real work.
[herdr web UI on every host](../../archived/feature/2026-10-02-herdr-web-ui-everywhere.md)
now covers the phone and multi-machine use case with OMP threads.

## Proposal

After a trial period of daily use of `herdr.sgiath.dev`, choose one:

1. Keep `services.t3code` as a fallback for its built-in settle and worktree
   flow.
2. Remove it from Vesta, Ceres and Pallas: the NixOS module and vhosts, the HM
   user service and packages, the `t3code-*-token` secrets in
   `secrets/vesta.yaml`, and the `t3` entries in `sgiath.nebula.services`.

## Alternatives considered

- **Remove it now**: loses the fallback before herdr-web-ui has proven itself;
  upstream is young and releases nearly daily.

## Acceptance criteria

- Either a recorded decision to keep T3 Code with the reason, or no
  `t3code` reference left in the flake and `t3.sgiath.dev` no longer resolves.

## Risks

- Removing it drops the only UI with built-in settle and worktree creation.

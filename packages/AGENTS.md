# packages

## OVERVIEW

Custom packages exposed through Snowfall as `sgiath.<name>` and registered manually in `packages/default.nix`.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Register package | `packages/default.nix` | Keep attr map alphabetized. |
| Package recipe | `packages/<name>/default.nix` | One derivation per package unless existing package is composite. |
| Version updater | `packages/<name>/update.sh` | Required for externally versioned packages. |
| Extra asset hashes | package-local helper script | Example: `dnd5etools/update-img-hashes.sh`. |

## CONVENTIONS

- Standard layout: `packages/<name>/default.nix` plus executable `update.sh` when upstream can update.
- `bird` is the main exception: it comes from flake input `bird-src`, a local absolute path.
- Updaters start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Define `SCRIPT_DIR` and `DEFAULT_NIX`; scripts must work from any current directory.
- Accept an optional version when upstream has tags/releases; otherwise derive a pseudo-version from metadata.
- Read current version from `default.nix`; if unchanged, print already-current and exit before prefetch/build work.
- Hash fields by ecosystem: `hash` for fetchers, `vendorHash` for Go, `cargoLock.outputHashes` for Rust git deps, `npmDepsHash`/`pnpmDeps.hash` for JS, `outputHash` for fixed-output derivations.
- Finish with a concrete validation command, usually `nix build '.#<package>'`.

## ANTI-PATTERNS

- Do not add a package directory without adding it to `packages/default.nix`.
- Do not use `nix-shell` shebangs; add updater tools to `shells/default/default.nix`.
- Do not copy `relay-tester`'s `nix-shell -p cargo rustc --run ...` pattern into new scripts.
- Do not update only one hash in composite packages (`eve-flipper`, `clawpatch`, `dnd5etools`).
- Do not forget `dnd5etools/update-img-hashes.sh` when image assets changed.
- Keep brittle `sed`/`perl` rewrites scoped tightly; formatting changes can break them.

## VALIDATION

```bash
nix develop
nix build '.#<package>'
```

## NOTES

- Some packages disable checks because upstream tests need network or external services (`nak`, `relay-tester`, `eve-flipper`).
- `kimi-webbridge` versions from HTTP `Last-Modified`, not release tags.
- `linear-cli` uses fixed-output hashing rather than a normal source build.
- `herdr-web-ui` hashes its `bun install` output as a fixed-output `node_modules` derivation (`.#herdr-web-ui.node_modules`); bun fetches only the build platform's prebuilts, so the package is x86_64-linux only. Its `update.sh` ignores the upstream `remote-v*` bridge-bundle tags.
- `t3code-nightly` (prebuilt Node SEA tarball) and `t3code-nightly-desktop` (AppImage) share `t3code-nightly/sources.json`; only `t3code-nightly/update.sh` exists and it rewrites that file from the release's `SHA256SUMS` and `nightly-linux*.yml` without downloading the artifacts. The SEA must keep `dontStrip`, and its `autoPatchelf` runs explicitly in `postFixup` because the completions step executes it. The desktop AppImage is extracted and autoPatchelf'd, not wrapped with `appimageTools.wrapType2`: that bubblewrap user namespace shows `/nix/store` as owned by `nobody`, so ssh rejects the Home Manager `~/.ssh/config` and SSH environments fail.
- Both nightly wrappers set `T3CODE_CLOUDFLARED_PATH` to nixpkgs `cloudflared`, so T3 Connect never downloads its pinned relay client. `t3code-nightly-device-tools` builds the npm tools T3 would otherwise `npm install` into `~/.t3/tools/<name>/<version>` (`expo-device-hub` for Device hub, `agent-device` for Agent device access, which also carries the Android snapshot/IME helper APKs). Their versions come from `DEVICE_HUB_VERSION`/`AGENT_DEVICE_VERSION` in upstream `apps/server/src/device/DeviceToolchain.ts` at the pinned nightly tag; `t3code-nightly/update.sh` calls `t3code-nightly-device-tools/update.sh`, which regenerates the per-tool `package-lock.json` (consumed by `importNpmLock`) and hashes `node-datachannel`'s napi prebuilt into its `sources.json`. Install scripts are skipped because that prebuilt download needs network.

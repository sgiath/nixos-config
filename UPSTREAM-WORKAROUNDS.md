# Upstream workarounds

The single registry of everything in this repository that patches, forks, pins,
vendors, or otherwise adapts upstream software, plus security and test
exceptions. Code comments, README sections and Agent Notes may link here; they
must not keep a second inventory.

- **Active register:** every case that exists because upstream (or the selected
  pin) is missing a fix, has an incompatible ABI/build contract, or needs an
  exception. Each record states why, the live upstream status, what the
  *selected* source contains, the removal gate, and how to validate.
- **Deliberate choices:** product/customization decisions that look like
  overrides but are not waiting on upstream. They are listed by group so they are
  not misreported as stale workarounds; they have no upstream removal gate.
- **Resolved history:** short record of verified clean cutovers.

Baseline of the current evidence: repository `c2ffb23b`, checked 2026-10-01.
Root pins at that time: `nixpkgs` b4fd65b1 (lock node `nixpkgs_4`),
`home-manager` c8ecc29e (`home-manager_2`), `hyprland` 5c9377c1 (v0.56.1; its
own nixpkgs 61b7c44c), `comfyui` 58f91b00 (its own nixpkgs dc5d91f8, lock node
`nixpkgs`), `sops-nix` 16954c1c, `snowfall-lib` 6ee3542c, `nixpkgs-master`
424084aa, `nixpkgs-ksa` 670a3617. Re-resolve them for each manual review; never read
bare `nodes.nixpkgs`/`nodes.home-manager` from `flake.lock`, those are nested
dependency nodes.

## Manual review

Invoke `/skill:review-upstream-workarounds` when you want fresh upstream checks.
The [project skill](.omp/skills/review-upstream-workarounds/SKILL.md) defines the
workflow. Reviews do not run automatically at session startup.

Adding or changing a workaround updates its record in the same change: stable
ID, where, why, upstream URL + status, selected-pin evidence, removal gate,
validation. Use a new ID only for a new case; never reuse an ID.

### Read-only commands

Run from the checkout root. Network access is needed for `gh`/`curl`. Evaluation
and source-only fetches may populate the Nix store for inspection, but must use
`--no-update-lock-file`; package/full-system builds remain outside the review.

```bash
# Root input revisions and store paths (name the field `source`, not `outPath`,
# or Nix coerces the whole input to a string and the rev is lost).
nix eval --impure --json --no-update-lock-file --expr \
  'let flake = builtins.getFlake (toString ./.); in builtins.mapAttrs (_: input: { rev = input.rev or null; source = toString input.outPath; }) flake.inputs'

# Nested pins (examples)
nix eval --impure --raw --no-update-lock-file --expr \
  '(builtins.getFlake (toString ./.)).inputs.hyprland.inputs.nixpkgs.rev'
nix eval --impure --raw --no-update-lock-file --expr \
  '(builtins.getFlake (toString ./.)).inputs.comfyui.inputs.nixpkgs.rev'

# What a full system selects (always go through nixosConfigurations;
# never evaluate Home Manager outputs on their own)
nix eval --raw --no-update-lock-file .#nixosConfigurations.vesta.pkgs.pihole-ftl.version
nix eval --raw --no-update-lock-file .#nixosConfigurations.ceres.config.hardware.graphics.package.version
# Fetch selected source for inspection; this does not build FTL or switch a host.
nix build --no-link --print-out-paths --no-update-lock-file .#nixosConfigurations.vesta.pkgs.pihole-ftl.src

# Upstream status
gh api repos/OWNER/REPO/pulls/N --jq '{state, merged_at, merge_commit_sha, base: .base.ref}'
gh api repos/OWNER/REPO/issues/N --jq '{state, closed_at}'
gh api repos/OWNER/REPO/releases/latest --jq '{tag_name, published_at}'
# Does PINNED contain FIX? status "ahead"/"identical" = yes; "behind"/"diverged" = no
gh api repos/OWNER/REPO/compare/FIX_SHA...PINNED_REV --jq '{status, ahead_by, behind_by}'
gh api "repos/OWNER/REPO/contents/PATH?ref=REV" --jq .content | base64 -d

# Electron support window for bundled runtimes
curl -fsSL https://releases.electronjs.org/schedule.json \
  | jq '.[] | select(.version | test("^(33|42)\\."))'
```

### Validation profiles

Full-system validation is required for any removal or change; package-only
builds supplement it and never replace it. All commands are proposals until run.

| Profile | Command |
| --- | --- |
| `ceres` | `nix build --no-link --no-update-lock-file .#nixosConfigurations.ceres.config.system.build.toplevel` |
| `pallas` | same with `pallas` |
| `vesta` | same with `vesta` |
| `juno1` | `nix eval --raw --no-update-lock-file .#nixosConfigurations.juno1.config.system.build.toplevel.drvPath`, then a native build on the authorized aarch64 builder |
| `iso` | `nix build --no-link --no-update-lock-file .#install-isoConfigurations.live` (runtime only on disposable media/VM) |
| `desktop` | `ceres` + `pallas` |
| `all` | `ceres` + `pallas` + `vesta` + `juno1` + `iso` |

Runtime checks in records are required future checks unless the record's
**Exercised** line says otherwise. Never print or read secret values for a check.

### Status values

| Status | Meaning |
| --- | --- |
| `required` | The selected source still lacks the fix / the constraint still holds. |
| `candidate` | Evidence says the selected source no longer needs it; removal waits for an authorized change that passes the gate. |
| `unverified` | Local rationale is undocumented or unreproduced; keep until established, never remove on absence of evidence. |
| `watch` | Dated deadline; escalate to `expired` after it. |
| `expired` | Security deadline passed (e.g. EOL runtime); report on each manual review. |
| `decision` | Needs an explicit owner decision (accept or remove), not an upstream event. |
| `dormant` | Present in source but no configured system uses it; check during manual reviews, validate runtime on enablement. |
| `unknown` | The latest review's check failed; retained. |

## Active register

| ID | Kind | Status | Profile |
| --- | --- | --- | --- |
| [`pihole-ftl-gcc16-unused-counter`](#pihole-ftl-gcc16-unused-counter) | temporary fix | required | vesta |
| [`davinci-resolve-21-1-republished-hash`](#davinci-resolve-21-1-republished-hash) | temporary fix | candidate | ceres |
| [`snowfall-flake-utils-plus-deferred-config`](#snowfall-flake-utils-plus-deferred-config) | vendored fork | required | all |
| [`sops-nix-build-go126-fork`](#sops-nix-build-go126-fork) | input fork | candidate | all |
| [`hyprland-glaze-release-freeze`](#hyprland-glaze-release-freeze) | input pin | required | desktop |
| [`ksa-unmerged-nixpkgs-package`](#ksa-unmerged-nixpkgs-package) | input fork | required | ceres |
| [`bird-unavailable-upstream-vendoring`](#bird-unavailable-upstream-vendoring) | vendored source | required | ceres, vesta |
| [`comfyui-rocm-int8-probe`](#comfyui-rocm-int8-probe) | temporary fix | required | ceres, juno1 |
| [`comfyui-python-package-set`](#comfyui-python-package-set) | compatibility | required | ceres, juno1 |
| [`comfyui-open-clip-broken-allowance`](#comfyui-open-clip-broken-allowance) | compatibility | required | ceres |
| [`comfyui-service-overlay-selection`](#comfyui-service-overlay-selection) | compatibility | required | ceres |
| [`comfyui-rocm-platform-guard`](#comfyui-rocm-platform-guard) | compatibility | required | ceres, juno1 |
| [`comfyui-qwen-memory-policy`](#comfyui-qwen-memory-policy) | compatibility | required | ceres |
| [`desktop-hyprland-mesa-abi`](#desktop-hyprland-mesa-abi) | ABI | required | desktop |
| [`portal-qt-theme-isolation`](#portal-qt-theme-isolation) | compatibility | unverified | desktop |
| [`legacy-wlroots-session-flags`](#legacy-wlroots-session-flags) | compatibility | unverified | desktop |
| [`amd-radv-nofibril`](#amd-radv-nofibril) | compatibility | unknown | ceres |
| [`satty-floating-hack`](#satty-floating-hack) | compatibility | required | desktop |
| [`quickshell-store-theme-restart`](#quickshell-store-theme-restart) | compatibility | required | desktop |
| [`stylix-release-check-suppression`](#stylix-release-check-suppression) | guard suppression | candidate | desktop |
| [`tmux-sessionizer-session-target`](#tmux-sessionizer-session-target) | temporary fix | required | all |
| [`home-manager-gpg-ssh-unit-cycle`](#home-manager-gpg-ssh-unit-cycle) | temporary fix | candidate | all |
| [`pihole-first-run-setup-retry`](#pihole-first-run-setup-retry) | temporary fix | required | vesta |
| [`searx-json-secret-interpolation`](#searx-json-secret-interpolation) | temporary fix | required | vesta |
| [`executor-state-ownership-migration`](#executor-state-ownership-migration) | data migration | required | vesta |
| [`executor-registry-image-version-selection`](#executor-registry-image-version-selection) | updater constraint | required | vesta |
| [`failure-watcher-herdr-idle-before-prompt`](#failure-watcher-herdr-idle-before-prompt) | compatibility | required | all |
| [`ollama-rocm-gfx-override-dormant`](#ollama-rocm-gfx-override-dormant) | compatibility | dormant | ceres |
| [`katrain-kivy-python-api`](#katrain-kivy-python-api) | compatibility | required | ceres |
| [`katrain-kivy-cython-long`](#katrain-kivy-cython-long) | temporary fix | required | ceres |
| [`katrain-chardet-major-version`](#katrain-chardet-major-version) | compatibility | required | ceres |
| [`katrain-bundled-katago-appimage`](#katrain-bundled-katago-appimage) | compatibility | required | ceres |
| [`katrain-opencl-test-exclusion`](#katrain-opencl-test-exclusion) | test exception | required | ceres |
| [`agent-orchestrator-tmux-locale-shim`](#agent-orchestrator-tmux-locale-shim) | temporary fix | required | desktop |
| [`agent-orchestrator-go-patchelf-rpath`](#agent-orchestrator-go-patchelf-rpath) | temporary fix | required | desktop |
| [`agent-orchestrator-angle-dlopen`](#agent-orchestrator-angle-dlopen) | compatibility | required | desktop |
| [`whiteboard-angle-runpath`](#whiteboard-angle-runpath) | compatibility | required | desktop |
| [`whiteboard-cli-desktop-environment`](#whiteboard-cli-desktop-environment) | compatibility | required | desktop |
| [`openclaw-desktop-deep-link-wrapper`](#openclaw-desktop-deep-link-wrapper) | temporary fix | required | desktop |
| [`openclaw-desktop-remote-ssh-limitation`](#openclaw-desktop-remote-ssh-limitation) | known limitation | required | desktop |
| [`openclaw-desktop-asset-aware-updater`](#openclaw-desktop-asset-aware-updater) | updater constraint | required | desktop |
| [`xurl-versioned-user-agent-test`](#xurl-versioned-user-agent-test) | temporary fix | required | ceres, vesta, juno1 |
| [`nak-network-check-disable`](#nak-network-check-disable) | test exception | required | package only (not installed) |
| [`relay-tester-check-disable`](#relay-tester-check-disable) | test exception | candidate | package only (not installed) |
| [`cross-architecture-nixos-rebuild-no-reexec`](#cross-architecture-nixos-rebuild-no-reexec) | compatibility | required | ceres, juno1 |
| [`burn-iso-hybrid-mbr-key-partition`](#burn-iso-hybrid-mbr-key-partition) | compatibility | required | iso |
| [`agent-orchestrator-bundled-electron`](#agent-orchestrator-bundled-electron) | security exception | expired | desktop |
| [`clawpatch-trust-lockfile`](#clawpatch-trust-lockfile) | security exception | decision | ceres, vesta, juno1 |
| [`whiteboard-bundled-electron`](#whiteboard-bundled-electron) | security exception | watch (2026-10-20) | desktop |

### Flake inputs, overlays and vendoring

#### `pihole-ftl-gcc16-unused-counter`

- **Where:** `overlays/sgiath/default.nix` (`pihole-ftl`), `overlays/sgiath/pihole-ftl-unused-counter.patch`.
- **Why:** FTL 6.7.1 fails under GCC 16 `-Werror=unused-but-set-variable` (unused `i` in `sanitize_dns_hosts`). The patch deletes only that counter; traversal and sanitization are unchanged, `-Werror` stays on.
- **Upstream:** [pi-hole/FTL#2939](https://github.com/pi-hole/FTL/pull/2939) merged 2026-07-07 into `development` (c184294f). Latest release still v6.7.1 (2026-09-19); release and development diverge, so merge ancestry is misleading.
- **Selected pin:** root nixpkgs packages FTL 6.7.1; v6.7.1 `src/config/validator.c:824-825` still has `int i = 0` / `i++`.
- **Remove when:** the FTL source selected by root nixpkgs lacks the counter or carries the upstream correction. Remove overlay attr and patch together; never by disabling `-Werror`.
- **Validate:** `vesta`; runtime: `pihole-ftl` healthy, local `dns.hosts` names and public DNS still answer.
- **Exercised:** focused package build, IPv4/IPv6 sanitizer smoke and full Vesta evaluation succeeded when the backport landed.

#### `davinci-resolve-21-1-republished-hash`

- **Where:** `overlays/sgiath/default.nix` (`davinci-resolve-dir`, `davinci-resolve-studio`); only consumer commented out in `homes/x86_64-linux/sgiath@ceres/default.nix`.
- **Why:** Blackmagic republished 21.1 archives without a version bump; the overlay applied the hash fix from a nixpkgs PR to the pinned package directory.
- **Upstream:** [NixOS/nixpkgs#562336](https://github.com/NixOS/nixpkgs/pull/562336) merged 2026-09-18 (748f45f3).
- **Selected pin:** root nixpkgs contains the merge (compare `behind_by=0`); `package.nix` already has the corrected Studio and non-Studio hashes. Forcing `nixosConfigurations.ceres.pkgs.davinci-resolve-studio` fails IFD with "Reversed (or previously applied) patch detected". Normal system evaluation does not force it (dormant).
- **Remove when:** already satisfied at source level. In an authorized change delete `davinci-resolve-dir` and the Studio override so upstream `davinci-resolve-studio` is used; keep the commented consumer as is.
- **Validate:** `ceres` plus force/build `.#nixosConfigurations.ceres.pkgs.davinci-resolve-studio`; runtime (licensed workstation): launch, open project, import/play media, GPU processing.

#### `snowfall-flake-utils-plus-deferred-config`

- **Where:** `flake.nix` (`flake-utils-plus-fixed` input; `snowfall-lib.inputs.flake-utils-plus.follows`), `vendor/flake-utils-plus-fixed/flake.nix`, `vendor/flake-utils-plus-fixed/lib/mkFlake.nix`, `vendor/flake-utils-plus-fixed/lib/options.nix`.
- **Why:** upstream `mkFlake` pre-evaluates `hostConfig` and forces `nixpkgs.config = mkForce {}`, breaking host `nixpkgs.config`. The wrapper (based on upstream 3542fe91) passes channel config/overlays as NixOS module definitions, keeps raw channel data in `__flakeUtilsPlus`, and migrates `nix.nixPath` to `nix.settings.nix-path`.
- **Upstream:** [flake-utils-plus#162](https://github.com/gytis-ivaskevicius/flake-utils-plus/issues/162); [#163](https://github.com/gytis-ivaskevicius/flake-utils-plus/pull/163) open, unmerged (head 10d81075), and **not equivalent**: it injects external `nixpkgs.pkgs` and documents that host `nixpkgs.config` still fails. Master a00f6f51 still has the eager evaluation. Snowfall main is the pinned 6ee3542c ([snowfallorg/lib#173](https://github.com/snowfallorg/lib/issues/173), maintainer call).
- **Remove when:** a selected upstream supports host `nixpkgs.config`, channel overlays/config, registry/input linking and `nix.settings.nix-path`. Then retarget the follows and delete the vendor tree. Merging #163 alone is insufficient; do not move host package policy into a new workaround to accommodate it.
- **Validate:** `all`; runtime (VM/host): Nix registry, input symlinks, `NIX_PATH`, representative overlaid packages.
- **Origin:** 26bbf25b (2026-08-09).

#### `sops-nix-build-go126-fork`

- **Where:** `flake.nix` (`sops-nix.url = github:c2fc2f/sops-nix/buildGo126Module`), used by NixOS and Home Manager module lists.
- **Why:** the fork's locked commit 16954c1c ("Bump go to stable") moves to Go 1.26 / `buildGoModule`.
- **Upstream:** [Mic92/sops-nix 16954c1c](https://github.com/Mic92/sops-nix/commit/16954c1c360c3dc4d4b3b3e64df59f7e89452cb1) is in Mic92 master (5efb5a6f); fork branch is behind 7, ahead 0.
- **Selected pin:** the exact pinned commit is already upstream. Original motivation beyond the Go bump is undocumented (switched in 6ffdb793).
- **Remove when:** source-only cutover to `github:Mic92/sops-nix` at a revision containing 16954c1c (ideally the same revision), keeping `nixpkgs.follows` and module wiring.
- **Validate:** `all`; runtime: sops units succeed, secret files exist with expected owner/mode (never print values), one dependent service starts.

#### `hyprland-glaze-release-freeze`

- **Where:** `flake.nix` (`hyprland.url = github:hyprwm/Hyprland/v0.56.1`, comment block above it; `hyprland-plugins` follows it), `scripts/update-inputs.sh` (the `# pin to v0.56.1` marker freezes the updater).
- **Why:** v0.56.x `CMakeLists.txt:133` requires `find_package(glaze 7...<8 QUIET)` and falls back to network `FetchContent`; root nixpkgs ships glaze 8.4.0. Why v0.56.1 rather than main was chosen (87644f14) is undocumented; do not claim v0.56.1 solves glaze 8.
- **Upstream:** [Hyprland 91f29f23](https://github.com/hyprwm/Hyprland/commit/91f29f23bb691462f8aa6171b964069aebc37910) removed the limit on main (2026-08-04). [Latest release](https://github.com/hyprwm/Hyprland/releases/latest) v0.56.2 does not contain it.
- **Stale comment:** `flake.nix` says "Unpinned from v0.56.2"; the input is pinned to v0.56.1. Fix the prose in the same change that next touches this pin.
- **Side finding:** evaluating the raw `nixosConfigurations.ceres.pkgs.hyprland.version` failed on missing `hyprland-guiutils` (the `default` overlay omits the dependency overlays). Not shown to affect the full systems.
- **Remove when:** a release whose actual source accepts the selected glaze (or ships a sandbox-safe dependency) exists; verify full Hyprland dependency overlay wiring, keep Mesa/portal/plugins matched, then update the pin and the updater marker.
- **Validate:** `desktop`; runtime: log in, `hyprctl version`, displays, acceleration, screen sharing, plugins.

#### `ksa-unmerged-nixpkgs-package`

- **Where:** `flake.nix` (`nixpkgs-ksa`), `overlays/sgiath/default.nix` (`pkgs-ksa`, `ksa`), consumer `modules/home/gaming/role.nix`.
- **Why:** Kitten Space Agency is not in root nixpkgs; the fork branch packages 2026.5.7.4397.
- **Upstream:** [NixOS/nixpkgs#492242](https://github.com/NixOS/nixpkgs/pull/492242) open, unmerged; head equals the pinned 670a3617.
- **Remove when:** root nixpkgs has `ksa` at the needed version with equivalent runtime deps; remove input, import and overlay attr together. Keep it gaming-only (not on Pallas).
- **Validate:** `ceres` plus `.#nixosConfigurations.ceres.pkgs.ksa`; runtime: game reaches playable state.

#### `bird-unavailable-upstream-vendoring`

- **Where:** `vendor/bird/`, `packages/bird/default.nix` (builds from `vendor/bird`).
- **Why:** upstream is unreachable; the vendored 0.8.0 tree is also locally modified (native Linux Chromium cookie source, dependency refresh, e.g. d9fce644).
- **Upstream:** [steipete/bird](https://github.com/steipete/bird) returned HTTP 404 from the API and the web (deleted vs private unknown).
- **Remove when:** a fetchable immutable upstream preserves all current CLI behavior and the native open-Chromium cookie reading (see deliberate group `bird-product`). Compare against the local tree, not the version string.
- **Validate:** `ceres`, `vesta` plus `pkgs.sgiath.bird`; runtime: `bird --help`; an authenticated read only with explicit authorization, never printing credentials.

### ComfyUI (Ceres)

Common runtime check for every ComfyUI record: `systemctl show comfyui.service -p ActiveState -p ExecStart`, `GET http://127.0.0.1:8188/system_stats` and `/object_info`, then run both seeded Qwen workflows (`int8.json`, `int8-enhanced.json`) to completion. Eval/import success is not image-generation proof. Overlay/platform changes also need `juno1` to prove the x86-only code stays lazy.

#### `comfyui-rocm-int8-probe`

- **Where:** `overlays/comfyui/default.nix` (`applyPatches` override), `overlays/comfyui/rocm-int8-compute.patch`.
- **Why:** PyTorch 2.10.0+rocm7.1 lacks the hipBLASLt gfx1030 Tensile library. The patch probes `torch._int_mm` once per AMD device in `supports_int8_compute`, caching `False` on `RuntimeError` so ComfyUI uses its existing dequantized full-precision path; CPU and non-AMD paths are not probed.
- **Upstream:** `supports_int8_compute` has no ROCm probe in ComfyUI 0.37.0 ([73c9bad4](https://github.com/Comfy-Org/ComfyUI/blob/73c9bad4d21e7addbe1d13bc92eee0f1431b017d/comfy/model_management.py#L2049-L2065)), 0.38.0 or master 651ca296. [#16130](https://github.com/Comfy-Org/ComfyUI/pull/16130) and [#16285](https://github.com/Comfy-Org/ComfyUI/pull/16285) are related, not equivalent. No ROCm `_int_mm` issue found (search absence is not proof). comfyui-nix main = latest release = pin 58f91b00 (v0.37.0-r1).
- **Remove when:** the selected comfyui-nix package contains an equivalent capability check, or its selected ROCm wheel runs INT8 GEMM on gfx1030. Inspect the fetched/patched source and actual wheel. Cut over the package construction, service selection and `json-repair` together.
- **Validate:** `ceres` + `juno1`; runtime: with packaged Python, `torch._int_mm` and `supports_int8_compute` for `cuda:0` and `cpu`, then both workflows without HIPBLAS errors.
- **Exercised (2026-10-01):** deployed packaged Python reported gfx1030; native probe hit missing `TensileLibrary_lazy_gfx1030.dat`/`HIPBLAS_STATUS_INVALID_VALUE`; GPU `False` (cached), CPU `True`. No image generated.

#### `comfyui-python-package-set`

- **Where:** `overlays/comfyui/default.nix` (`import comfyui-nix.inputs.nixpkgs`, upstream `versions.nix`, `python-overrides.nix`).
- **Why:** builds with comfyui-nix's own nixpkgs (dc5d91f8), not root nixpkgs, so upstream Python overrides (Python 3.12, torch 2.10.0+rocm7.1) still match and unchanged derivations share store paths.
- **Upstream:** [python-overrides.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/nix/python-overrides.nix); [comfyui-nix#81](https://github.com/utensils/comfyui-nix/issues/81) closed 2026-08-14, which does not prove root-nixpkgs compatibility.
- **Remove when:** the local source patch no longer needs a private package construction (prefer upstream package + `withExtraPythonPackages`), or root pkgs is proven compatible for the full GPU Python scope with no duplicate torch stack. Keep `json-repair` and ROCm library order.
- **Validate:** `ceres` + `juno1`; runtime: import torch/torchvision/torchaudio/json_repair from the service Python, ROCm device visible, both workflows.

#### `comfyui-open-clip-broken-allowance`

- **Where:** `overlays/comfyui/default.nix` (`allowBrokenPredicate` for `open-clip-torch`).
- **Why:** the private package set marks `open-clip-torch` broken; this mirrors upstream comfyui-nix ([flake.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L177-L184), tests disabled in [python-overrides.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/nix/python-overrides.nix#L954-L959)). Not an insecure-package exemption.
- **Remove when:** the selected nixpkgs/Python scope builds `open-clip-torch` without the predicate, or the closure no longer contains it. Upstream dropping its own exception is a prompt to check, not proof.
- **Validate:** `ceres`; runtime: `import open_clip` from service Python, both workflows.

#### `comfyui-service-overlay-selection`

- **Where:** `modules/nixos/services/comfyui.nix` (`package = pkgs.comfy-ui-rocm`).
- **Why:** upstream module defaults `packageSet` to the flake's own packages ([flake.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L348-L357)), which would bypass the INT8 patch and `json-repair`. Upstream `extraPythonPackages` cannot be combined with a custom package.
- **Remove when:** the default package already contains the INT8 fix; migrate `json-repair` to `services.comfyui.extraPythonPackages` in the same cutover.
- **Validate:** `ceres`; inspect evaluated `ExecStart` package; runtime: enhancer nodes registered, both workflows.

#### `comfyui-rocm-platform-guard`

- **Where:** `overlays/comfyui/default.nix` (`isLinux && isx86_64` branch, `prev.comfy-ui-rocm` fallback).
- **Why:** upstream ROCm package exists only on x86_64 Linux ([flake.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L332-L337)); keeps aarch64 (Juno) evaluation lazy.
- **Remove when:** upstream supports ROCm on another architecture and that platform's wheels are proven; do not enable Ceres's ROCm service on aarch64 because generic ComfyUI supports it.
- **Validate:** `ceres` + `juno1`.

#### `comfyui-qwen-memory-policy`

- **Where:** `systems/x86_64-linux/ceres/qwen-image.nix` (VRAM reserve), `systems/x86_64-linux/ceres/qwen-image/int8.json`, `int8-enhanced.json` (CPU text encoder placement).
- **Why:** 5 GiB VRAM reserve for casts/attention scratch on the 16 GiB RX 6950 XT and CPU placement of the Qwen3VL encoder, needed with INT8 storage + full-precision fallback.
- **Upstream:** [Qwen-Image-2.1 ace0edeb](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/tree/ace0edeb3791a594ddfa36ed5f41a178a394e921) and the ComfyUI revisions above. Hardware fit, not an upstream bug.
- **Remove when:** the selected model/kernel/memory management fits both workflows cold and warm (including enhancer load transitions) without the reserve or CPU placement. Update seeded and saved workflows consistently.
- **Validate:** `ceres`; runtime: 1024×1024 baseline and enhanced workflows with memory observation.

### Desktop and graphics

#### `desktop-hyprland-mesa-abi`

- **Where:** `modules/nixos/desktop/wayland.nix` (`hardware.graphics.package`/`package32` from `inputs.hyprland.inputs.nixpkgs`); enabled by `modules/nixos/hardware/gpu.nix`. README "Desktop graphics" explains the failure.
- **Why:** root Mesa can require a newer glibc than the pinned compositor loads, causing `Cannot open backend: no allocator available` (5299bbf2). Evaluated 2026-10-01: selected Mesa 26.1.5 with Hyprland's glibc 2.42 vs root Mesa 26.2.3 / glibc 2.44.
- **Upstream:** [Hyprland on NixOS (0.54)](https://wiki.hypr.land/0.54.0/Nix/Hyprland-on-NixOS/) still recommends Mesa from Hyprland's nixpkgs. [hyprwm/Hyprland#5148](https://github.com/hyprwm/Hyprland/issues/5148) is closed (2024-03-17), not proof for the current pins.
- **Remove when:** compositor, portal and 64/32-bit Mesa share a coherent package universe (e.g. Hyprland follows root nixpkgs, or its nixpkgs equals root) and the session runs without the override.
- **Validate:** `desktop`; runtime: running Hyprland and `/run/opengl-driver` paths, no loader/GLIBC errors in journal, accelerated rendering, screen sharing; on Ceres a 32-bit Steam/Proton game.

#### `portal-qt-theme-isolation`

- **Where:** `modules/nixos/desktop/wayland.nix` (`xdg-desktop-portal-hyprland` unsets `QT_QPA_PLATFORMTHEME`, `QT_STYLE_OVERRIDE`).
- **Why:** [INFERENCE] isolates the Qt6 share picker from global Qt theme plugins/styles; no failure or upstream fix recorded.
- **Upstream:** pinned portal 08d99f72 uses Qt6 widgets; master e87ae782. [xdg-desktop-portal-hyprland#145](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/145) closed but about ignored themes, not this isolation.
- **Remove when:** the selected portal starts and captures with the variables inherited, with intended theming.
- **Validate:** `desktop`; runtime: browser screen-share picker, capture window/monitor, portal journal clean.

#### `legacy-wlroots-session-flags`

- **Where:** `modules/nixos/desktop/wayland.nix` (`WLR_RENDERER_ALLOW_SOFTWARE`, `WLR_NO_HARDWARE_CURSORS`).
- **Why:** legacy wlroots software-render/cursor flags; neither name occurs in pinned Hyprland `src/`. Possibly stale, but other consumers are not ruled out.
- **Upstream:** [selected Hyprland source](https://github.com/hyprwm/Hyprland/tree/5c9377c15f85c50648f35ca5a213754f95b93ca0/src) has no consumer found for either flag; [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots) remains a possible consumer family. No original failure or fixed revision is identified.
- **Remove when:** actual session consumers are inventoried and cursors/rendering work without each flag on AMD and NVIDIA.
- **Validate:** `desktop`; runtime: login, cursor movement and capture, monitor hotplug, wlroots-based apps.

#### `amd-radv-nofibril`

- **Where:** `modules/nixos/hardware/gpu-amd.nix` (`RADV_PERFTEST=nofibril`; RADV selection itself is deliberate).
- **Why:** undocumented. [Mesa envvars docs](https://docs.mesa3d.org/envvars.html) do not mention it; Mesa GitLab source could not be fetched (timed out), so recognition in Mesa 26.1.5 is unverified.
- **Remove when:** the selected RADV's handling of the flag is established and a shader-compilation/game workload behaves the same without it.
- **Validate:** `ceres`; runtime: controlled Vulkan/game comparison.

#### `satty-floating-hack`

- **Where:** `modules/home/desktop/hyprland/screenshot.nix` (`--floating-hack` plus window rule for `com.gabm.satty`).
- **Why:** Satty's own compositor-dependent floating workaround ([command_line.rs](https://github.com/Satty-org/Satty/blob/f578432a68f3930cc5fd52f2f7d99d54aff0d9ae/cli/src/command_line.rs#L36-L39), still on main); selected Satty 0.22.0.
- **Remove when:** the window rule alone floats Satty for both region and monitor flows.
- **Validate:** `desktop`; runtime: SUPER+S and SUPER+SHIFT+S, annotate, save, copy.

#### `quickshell-store-theme-restart`

- **Where:** `modules/home/desktop/quickshell.nix` (`X-Restart-Triggers`), `modules/home/desktop/quickshell/config/Theme.qml`.
- **Why:** the file watcher does not notice the store theme symlink target changing during a switch ([QFileSystemWatcher](https://doc.qt.io/qt-6/qfilesystemwatcher.html) stops watching renamed files; exact case not reproduced).
- **Remove when:** the selected watcher picks up an atomic symlink replacement in live and packaged modes.
- **Validate:** `desktop`; runtime: change theme in a disposable branch, switch, verify colors/fonts/wallpaper update without losing app windows.

#### `stylix-release-check-suppression`

- **Where:** `modules/nixos/desktop/stylix.nix`, `modules/home/desktop/stylix.nix` (`enableReleaseChecks = false`).
- **Why:** silences Stylix/NixOS/HM release mismatch warnings. Evaluated 2026-10-01: all three report 26.11, so nothing is currently suppressed.
- **Upstream:** [stylix/release.nix](https://github.com/danth/stylix/blob/fb28acd59e2ac1984ec84fa496599d6b4bf3e690/stylix/release.nix#L9-L19).
- **Remove when:** checks evaluate clean on all systems and the input-tracking policy does not need mismatched releases.
- **Validate:** `desktop`; inspect themes only if inputs change.

### Terminal, agents and services

#### `tmux-sessionizer-session-target`

- **Where:** `modules/home/terminal/tmux.nix` (`postPatch` on `tmux-sessionizer`).
- **Why:** `Tmux::new_window` targets an unqualified session name, which tmux can resolve to a matching worktree window. The patch appends `:`.
- **Upstream:** [v0.6.1 tmux.rs](https://github.com/jrmoulton/tmux-sessionizer/blob/v0.6.1/src/tmux.rs) and main 15cc6462 still unqualified; latest release v0.6.1 = selected version.
- **Remove when:** the selected release qualifies the target and the collision scenario passes without the patch. Keep the popup bindings.
- **Validate:** `all`; runtime: run TMS from the popup in a session containing a window whose name starts with the target session name.
- **Exercised (2026-10-01):** isolated tmux 3.7c probe: `-t target` failed "index 0 in use", `-t target:` created the window in the right session.

#### `home-manager-gpg-ssh-unit-cycle`

- **Where:** `modules/home/terminal/gpg.nix` (`systemd.user.services."set-SSH_AUTH_SOCK"` forced `WantedBy`/`Before`).
- **Why:** HM ordered `set-SSH_AUTH_SOCK` against `gpg-agent-ssh.socket`, creating a unit cycle.
- **Upstream:** [home-manager e9cbe698](https://github.com/nix-community/home-manager/commit/e9cbe69850d67c2b472db8416faca7292960f99f) (2026-06-08); pinned [ssh-auth-sock.nix](https://github.com/nix-community/home-manager/blob/c8ecc29e5175452bee4a2aa1ba2383856d795338/modules/misc/ssh-auth-sock.nix#L121-L138) already skips socket providers.
- **Exercised (2026-10-01):** read-only Ceres `extendModules` comparison without the local override produced identical fields (`Before=[]`, `WantedBy=["default.target"]`).
- **Remove when:** authorized: delete only the override and its comment; all systems build; a real login shows no ordering cycle.
- **Validate:** `all`; runtime: `systemctl --user status gpg-agent-ssh.socket set-SSH_AUTH_SOCK.service`, `SSH_AUTH_SOCK` set, `ssh-add -L` lists expected keys.

#### `pihole-first-run-setup-retry`

- **Where:** `modules/nixos/services/pi-hole.nix` (`pihole-ftl-setup` `Restart=on-failure`, `RestartSec=5`).
- **Why:** on fresh state the upstream setup script creates `gravity.db`, signals FTL and posts lists immediately; the first request can fail "Database not available".
- **Upstream:** pinned [pihole-ftl-setup-script.nix](https://github.com/NixOS/nixpkgs/blob/b4fd65b198c599cbe814fcb9f42d25d021595ec9/nixos/modules/services/networking/pihole-ftl-setup-script.nix#L76-L95) still only probes API availability, not database reopen. No upstream issue/fix known.
- **Remove when:** the selected setup script waits for database readiness (or retries list submission) and a disposable fresh-state run provisions all lists without the retry. Never reset production Pi-hole state to test.
- **Validate:** `vesta`; runtime: disposable fresh-state setup succeeds, lists exist, DNS resolves; populated-state rerun stays idempotent.

#### `searx-json-secret-interpolation`

- **Where:** `modules/nixos/services/searx.nix` (`searx-init` replaced with `jq --rawfile`).
- **Why:** upstream `envsubst` interpolates secrets unescaped into JSON strings; jq encodes them correctly while keeping runtime credentials and restart wiring.
- **Upstream:** pinned [searx.nix](https://github.com/NixOS/nixpkgs/blob/b4fd65b198c599cbe814fcb9f42d25d021595ec9/nixos/modules/services/networking/searx.nix#L31-L37) still uses `envsubst`. No upstream issue recorded.
- **Remove when:** the selected module serializes credential strings safely at runtime; reconcile favicon/limiter generation first; keep restart wiring. Credential handling review belongs to the security model.
- **Validate:** `vesta`; runtime: fixture with special characters round-trips, `searx-init` and SearXNG start, a search works.

#### `executor-state-ownership-migration`

Also covers audit ID `executor-root-to-nonroot-state-migration`.

- **Where:** `modules/nixos/services/executor.nix` (tmpfiles `d` + recursive `Z` for uid/gid 65532 on `/data/executor`).
- **Why:** images up to 1.6.8 ran as root; selected 1.6.10 is distroless nonroot (`USER 65532`, [Dockerfile](https://github.com/UsefulSoftwareCo/executor/blob/3890d6f5e5efd1530f0dba0fe23ada95a39caf86/apps/host-selfhost/Dockerfile#L28)). `Z` migrates existing root-owned state; `d` stays as the ongoing rule.
- **Remove `Z` when:** every retained volume, restored backup and supported rollback target is already 65532-owned; keep the `d` rule aligned with the image UID.
- **Validate:** `vesta`; runtime: read-only owner check (`stat`/`find -not -user 65532`, no content reads), container start/restart, health and persistence.

#### `executor-registry-image-version-selection`

- **Where:** `scripts/update-executor.sh` (highest semver tag on `ghcr.io/rhyssullivan/executor-selfhost`).
- **Why:** not every GitHub release publishes an image (comment: 1.6.9 had none), so the updater follows registry tags, not releases. Concrete version pinning in the module (never `:latest`) is a separate deliberate rule.
- **Upstream:** [v1.6.10](https://github.com/UsefulSoftwareCo/executor/releases/tag/v1.6.10) is latest; registry also at 1.6.10.
- **Exercised (2026-10-01):** `scripts/update-executor.sh --dry-run` → "already at 1.6.10".
- **Remove when:** upstream guarantees a matching image for every release, or the updater design changes deliberately. Matching versions today are not enough.
- **Validate:** `vesta`; runtime: deployed image tag and Executor health after switch.

#### `failure-watcher-herdr-idle-before-prompt`

- **Where:** `modules/home/agents/system-failure-watcher.sh` (tab, `herdr agent start` without prompt, then `herdr agent prompt`), `modules/home/agents/system-failure-watcher.nix`.
- **Why:** an initial prompt makes OMP busy immediately, so Herdr never sees the idle-ready state its start command waits for.
- **Upstream:** selected Herdr v0.9.2 [agent.rs](https://github.com/herdrdev/herdr/blob/48292af8e33a08c8030b7f1512c8d0da739f5ab1/src/cli/agent.rs#L565) and HEAD d6b40d4e still require `interactive_ready` idle/done.
- **Remove when:** the selected Herdr accepts working-state startup with prompt delivery while preserving tracked-agent ownership.
- **Validate:** `all` where enabled; runtime: a synthetic failure opens exactly one tracked OMP tab with the intended prompt and no tmux fallback.

#### `ollama-rocm-gfx-override-dormant`

- **Where:** `modules/nixos/services/ollama.nix` (`ollama-rocm`, gfx 10.3.0 override); referenced from `systems/x86_64-linux/ceres/default.nix`.
- **Why:** spoofs the ROCm GPU target. Evaluated 2026-10-01: Ollama disabled on every host.
- **Upstream / selected pin:** [Ollama GPU support](https://docs.ollama.com/gpu) is the compatibility reference; no original issue or fixed revision is recorded. Root nixpkgs currently exposes `ollama-rocm` 0.34.4 (evaluated 2026-10-01), but this dormant service has no exercised GPU runtime.
- **Remove/change when:** before enabling, establish GPU support for the selected ROCm/Ollama and run real inference without spoofing.
- **Validate:** `ceres` on enablement; runtime: GPU detected, inference works.

### Local packages and scripts

#### `katrain-kivy-python-api`

- **Where:** `packages/katrain/default.nix` (Python 3.13 + package-local Kivy 2.3.1 with pyproject relaxations and mtdev path patch); consumer `homes/x86_64-linux/sgiath@ceres/default.nix`.
- **Why:** KaTrain 1.20.0 needs Python `>=3.11,<3.14` and Kivy 2.3.1 APIs; root nixpkgs has Kivy `2.3.1-unstable-2026-07-11`.
- **Upstream:** KaTrain latest v1.20.0 ([pyproject](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml)); Kivy latest 2.3.1; [kivy#9225](https://github.com/kivy/kivy/issues/9225) open (the local comment claiming Python 3.14 support merged is unreliable).
- **Remove when:** a selected nixpkgs dependency set satisfies KaTrain's actual Python/Kivy requirements and runs its UI/audio. Keep normal mtdev/build-dependency packaging if still needed.
- **Validate:** `ceres`; runtime: open KaTrain, load a game, UI and audio work.

#### `katrain-kivy-cython-long`

- **Where:** `packages/katrain/default.nix` (Kivy `postPatch` replacing Python 2 `long` in `weakproxy.pyx`, `context_instructions.pyx`, `opengl.pyx`).
- **Why:** Kivy 2.3.1 does not build with current Cython.
- **Upstream:** fixed on Kivy HEAD 9bd35c59 ([weakproxy.pyx](https://github.com/kivy/kivy/blob/9bd35c595760fe6909e6889b9aefe659a57f9eae/kivy/weakproxy.pyx#L250)), not in release 2.3.1 which is selected.
- **Remove when:** the selected Kivy contains these fixes and satisfies KaTrain; remove the replacements before `--replace-fail` breaks.
- **Validate:** `ceres`; runtime: KaTrain renders and analyzes a board.

#### `katrain-chardet-major-version`

- **Where:** `packages/katrain/default.nix` (`pythonRelaxDeps` for `chardet`).
- **Why:** KaTrain requires `chardet>=5.2.0,<6` ([pyproject L23](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml#L23)); root nixpkgs ships 6.0.0.post1.
- **Remove when:** the selected KaTrain accepts the selected chardet (or a compatible chardet is used).
- **Validate:** `ceres`; runtime: import non-UTF-8 SGF/NGF/GIB files, names/comments decode.

#### `katrain-bundled-katago-appimage`

- **Where:** `packages/katrain/default.nix` (extract bundled OpenCL KataGo AppImage, keep its `libzip.so.4`, drop Windows assets).
- **Why:** avoids FUSE/AppRun assumptions in the sandbox; nixpkgs libzip has another soname. Keeps upstream's engine rather than silently switching to nixpkgs KataGo.
- **Upstream:** [KaTrain KataGo dir](https://github.com/sanderland/katrain/tree/f4981cf905cece90085ce4e3967415d0c16d525f/katrain/KataGo); rationale is local, not re-reproduced.
- **Remove when:** the selected release ships a NixOS-compatible engine with OpenCL and ABI deps, or extraction becomes unnecessary.
- **Validate:** `ceres`; runtime: OpenCL engine analysis and a move on Ceres (`--help` is not proof).

#### `katrain-opencl-test-exclusion`

Also covers audit ID `package-katrain-opencl-test`.

- **Where:** `packages/katrain/default.nix` (disables only `test_ai_strategies`; temporary `HOME`).
- **Why:** the test constructs `KataGoEngine` and needs an OpenCL device; upstream itself skips it in CI ([test_ai.py](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/tests/test_ai.py#L17)).
- **Remove when:** the test becomes hermetic/CPU-backed, or the sandbox gets a deterministic software OpenCL.
- **Validate:** `ceres` plus package check phase; runtime as `katrain-bundled-katago-appimage`.

#### `agent-orchestrator-tmux-locale-shim`

- **Where:** `packages/agent-orchestrator/default.nix` (`resources/tmux/bin/tmux` replaced by a `/bin/sh` shim, shebang patching off).
- **Why:** bundled static-glibc tmux fails on `/usr/lib/locale`; AO copies tmux into `~/.ao/runtime/tmux/<version>-linux-x64` once and ignores inherited `AO_TMUX_BINARY`.
- **Upstream:** selected/latest v0.13.2; HEAD 53ba1e81 still stages and reuses the copied binary ([bundled-tmux.ts](https://github.com/Untrivial-ai/agent-orchestrator/blob/53ba1e81a4cd299e8d3e48767b06a185132ac54f/frontend/src/shared/bundled-tmux.ts)).
- **Remove when:** the selected release honors a system tmux path or ships tmux that works on NixOS, including same-version staged copies.
- **Validate:** `desktop`; runtime: isolated `AO_DATA_DIR`, start an agent session, relaunch, staged tmux still works. Never delete the user's `~/.ao`.

#### `agent-orchestrator-go-patchelf-rpath`

- **Where:** `packages/agent-orchestrator/default.nix` (move `ao` out of autoPatchelf's tree, set interpreter only).
- **Why:** adding an RPATH corrupts the Go daemon's `.dynamic` (SIGSEGV) with patchelf 0.15/0.18; root nixpkgs patchelf is 0.15.2.
- **Upstream:** [patchelf#457](https://github.com/NixOS/patchelf/issues/457) (related, closed 2023); latest [0.19.1](https://github.com/NixOS/patchelf/releases/tag/0.19.1). Neither proves the selected patchelf handles this binary.
- **Remove when:** the selected patchelf patches this `ao` without corruption and the daemon runs.
- **Validate:** `desktop`; runtime: `ao` CLI and real daemon/session startup.

#### `agent-orchestrator-angle-dlopen`

- **Where:** `packages/agent-orchestrator/default.nix` (`--add-needed libGL.so.1 libEGL.so.1` before autoPatchelf).
- **Why:** bundled ANGLE dlopens by soname in process scope.
- **Upstream:** selected/latest [Agent Orchestrator v0.13.2](https://github.com/Untrivial-ai/agent-orchestrator/releases/tag/v0.13.2). Local loader rationale is recorded; no equivalent upstream NixOS packaging fix was established.
- **Remove when:** a selected package supplies both libraries through a tested loader contract.
- **Validate:** `desktop`; runtime: AO GUI on Wayland without EGL/GL errors.

#### `whiteboard-angle-runpath`

- **Where:** `packages/whiteboard/default.nix` (runtime dlopen deps; libglvnd appended to all relevant RUNPATHs).
- **Why:** bundled ANGLE loads libEGL/libGL itself; `runtimeDependencies` only reaches executables.
- **Upstream:** selected/latest [v0.1.5](https://github.com/devdotfast/whiteboard/releases/tag/v0.1.5).
- **Remove when:** a selected package/native build resolves EGL/GL without the extra RUNPATH.
- **Validate:** `desktop`; runtime: `whiteboard-desktop` and CLI-launched desktop render a canvas on Wayland.

#### `whiteboard-cli-desktop-environment`

- **Where:** `packages/whiteboard/default.nix` (both wrappers add git/xdg-utils; desktop clears `ELECTRON_RUN_AS_NODE`/`VSCODE_*`; CLI sets `ELECTRON_RUN_AS_NODE`; desktop file `Exec` rewritten).
- **Why:** the CLI launches the desktop through `process.execPath`, bypassing the desktop wrapper.
- **Upstream:** selected/latest [Whiteboard v0.1.5](https://github.com/devdotfast/whiteboard/releases/tag/v0.1.5). No equivalent native-NixOS launcher contract or specific upstream fix was established.
- **Remove when:** the selected CLI routes launches through a supported wrapper keeping the environment on cold/warm launch.
- **Validate:** `desktop`; runtime: CLI-initiated and direct desktop launches from an environment containing the Electron/VSCode variables; git and external links work.

#### `openclaw-desktop-deep-link-wrapper`

- **Where:** `packages/openclaw-desktop/default.nix` (no `update-desktop-database` on PATH; shipped `OpenClaw.desktop` handles `openclaw://`).
- **Why:** runtime registration would point the handler at the unwrapped ELF.
- **Upstream:** selected [v2026.9.5](https://github.com/openclaw/openclaw/releases/tag/v2026.9.5).
- **Remove when:** the selected Tauri/plugin integration registers the wrapped launcher on NixOS, verified on cold launch.
- **Validate:** `desktop`; runtime: in an isolated desktop profile cold-open an `openclaw://` URI. Never overwrite the user's handler to test.

#### `openclaw-desktop-remote-ssh-limitation`

- **Where:** `packages/openclaw-desktop/default.nix` (FIXME; binary not patched).
- **Why:** remote gateway only tries `/usr/bin/ssh` and `/bin/ssh` (the FIXME mentions only the first); neither exists on NixOS, so remote-gateway mode does not work.
- **Upstream:** [remote_gateway.rs](https://github.com/openclaw/openclaw/blob/76d542b06c28386e9bfb2931d53dcea1f249ae06/apps/linux/src-tauri/src/remote_gateway.rs#L1045) on HEAD 76d542b0 still hardcodes both paths.
- **Resolve when:** the downloaded `.deb` actually includes a PATH/configurable ssh fix; then drop the FIXME.
- **Validate:** `desktop`; runtime: authorized SSH connection to a test gateway.

#### `openclaw-desktop-asset-aware-updater`

- **Where:** `packages/openclaw-desktop/update.sh` (highest stable release that has `OpenClaw-<version>-amd64.deb`).
- **Why:** latest project release (2026.9.7) has no Linux `.deb`; Linux `.deb` releases: 2026.9.5, 2026.9.4, 2026.8.2.
- **Upstream:** selected [v2026.9.5](https://github.com/openclaw/openclaw/releases/tag/v2026.9.5) has the required Linux asset; newer [v2026.9.7](https://github.com/openclaw/openclaw/releases/tag/v2026.9.7) does not. A newer project version alone is not a removal gate.
- **Remove when:** upstream has a durable Linux release-asset contract, or the package source type changes deliberately.
- **Validate:** `desktop`; runtime: OpenClaw local gateway and control UI after an update.

#### `xurl-versioned-user-agent-test`

- **Where:** `packages/xurl/default.nix` (ldflags `version.Version`, test expectation rewritten from `xurl/dev`).
- **Why:** upstream test hardcodes `xurl/dev` ([client_test.go L171](https://github.com/xdevplatform/xurl/blob/18dcb447f090667171ff23666a05d6d387e2aa73/api/client_test.go#L171)); selected v1.3.4 = HEAD.
- **Remove when:** the selected test no longer assumes `dev` under release ldflags. Keep runtime version injection.
- **Validate:** `ceres`, `vesta`, `juno1`; runtime: request to a disposable local HTTP endpoint shows `xurl/<version>`.

#### `nak-network-check-disable`

Also covers audit ID `package-nak-network-tests`.

- **Where:** `packages/nak/default.nix` (`doCheck = false`); package exposed, not installed (`modules/home/terminal/role.nix` entry commented).
- **Why:** some tests contact public Nostr relays ([cli_test.go](https://github.com/fiatjaf/nak/blob/8b1c3c9403d5fdce9f8e7c77b6d6fc6f1b86302c/cli_test.go#L127)); others are offline, so the blanket skip is broader than needed. Selected = latest v0.20.7.
- **Remove when:** upstream makes relay tests opt-in/hermetic, or packaging selects only offline tests that pass in the sandbox.
- **Validate:** package build with checks and network disabled (meaningful tests run) plus `ceres`/`vesta`/`juno1` boundary; runtime: `nak` help and offline encode/decode.

#### `relay-tester-check-disable`

Also covers audit ID `package-relay-tester-checks`.

- **Where:** `packages/relay-tester/default.nix` (`doCheck = false`, comment "Tests often require external relay environment"); package exposed, not installed.
- **Why/status:** pinned a8483f82 (= HEAD, no releases) has no `#[test]`/`#[cfg(test)]` in its 23 source files and no Cargo test target; `cargo test` should compile and report zero tests. The comment is likely stale, but the check phase has not been run.
- **Upstream:** selected [relay-tester a8483f82](https://github.com/mikedilger/relay-tester/tree/a8483f82f4965841faa92fae02105d4fd67d9117) equals live HEAD; [Cargo metadata](https://github.com/mikedilger/relay-tester/blob/a8483f82f4965841faa92fae02105d4fd67d9117/Cargo.toml) was inspected, but the sandbox check phase remains unexercised.
- **Remove when:** the default Rust check phase passes in the sandbox; then drop `doCheck = false` and its comment. `OPENSSL_NO_VENDOR` is normal integration, keep it.
- **Validate:** package build with default checks plus `ceres`/`vesta`/`juno1` boundary; never run the conformance suite against a public relay.

#### `cross-architecture-nixos-rebuild-no-reexec`

- **Where:** `packages/update/default.nix` (`--no-reexec` for `update --juno<N>`).
- **Why:** with `--build-host`/`--target-host` on aarch64, re-exec would replace the local x86_64 `nixos-rebuild` with the target's aarch64 binary.
- **Upstream:** [nixos-rebuild-ng](https://github.com/NixOS/nixpkgs/tree/b4fd65b198c599cbe814fcb9f42d25d021595ec9/pkgs/by-name/ni/nixos-rebuild-ng); no upstream change identified.
- **Remove when:** the selected rebuild keeps a runnable local binary for x86→aarch64 deployment.
- **Validate:** `ceres`, `juno1`; runtime: an authorized `update --juno1`.

#### `burn-iso-hybrid-mbr-key-partition`

- **Where:** `packages/burn-iso/default.nix` (settle/unmount, append `SGIATH-KEYS` via `sfdisk` to the hybrid ISO's MBR).
- **Why:** hybrid GPT/MBR geometry overlaps and the kernel reads the MBR; gptfdisk is unsuitable. No upstream issue; local layout evidence only.
- **Upstream:** no external fix/issue is identified: this is a local hybrid-ISO layout adaptation, not a package bug. Recheck the generated image geometry when its pinned inputs change.
- **Remove/change when:** the generated ISO geometry supports another strategy, proven on disposable media.
- **Validate:** `iso`; runtime: loop device/VM or expendable USB with fake keys boots and exposes the key partition.

### Security exceptions

Records from the security lifecycle audit. Bundled runtimes are invisible to nixpkgs `knownVulnerabilities`, so these deadlines are checked here. No `permittedInsecurePackages`, `allowInsecure`, `knownVulnerabilities` or `NIXPKGS_ALLOW_INSECURE` exists in the repository (2026-10-01).

#### `agent-orchestrator-bundled-electron`

Also covers audit IDs `package-agent-orchestrator-bundled-electron`, `agent-orchestrator-electron33` and the ABI half of `agent-orchestrator-bundled-abi-and-cli`.

- **Where:** `packages/agent-orchestrator/default.nix` (binary DEB with bundled Electron; comment on exact ABI).
- **Why:** `better-sqlite3` is compiled for the bundled Electron 33 ABI; swapping in nixpkgs Electron breaks it.
- **Status:** **expired** — Electron 33 EOL 2025-04-28 ([schedule](https://releases.electronjs.org/schedule.json)). Latest upstream [v0.13.2](https://github.com/Untrivial-ai/agent-orchestrator/releases/tag/v0.13.2) (2026-09-30, = selected) still pins `electron@33.4.11` in [frontend/package.json](https://github.com/Untrivial-ai/agent-orchestrator/blob/v0.13.2/frontend/package.json). Report on each manual review.
- **Remove when:** an upstream release ships a supported Electron major with `better-sqlite3` built for the same ABI. Do not replace Electron alone.
- **Validate:** inspect new release metadata and packaged runtime version; `desktop`; runtime: DB-backed create/open/persist flow and bundled `ao` CLI.

#### `clawpatch-trust-lockfile`

Also covers audit ID `package-clawpatch-trust-lockfile`.

- **Where:** `packages/clawpatch/default.nix` and `packages/clawpatch/update.sh` (`pnpm config set trust-lockfile true` in `prePnpmInstall`).
- **Why:** undocumented; added during the 0.6→0.7 bump. [INFERENCE] lets updates fetch dependencies younger than upstream's maturity window.
- **Effect:** bypasses upstream's `minimumReleaseAge: 2880` (48 h, [pnpm-workspace.yaml](https://github.com/openclaw/clawpatch/blob/v0.8.1/pnpm-workspace.yaml), unchanged in v0.8.2) and `trustPolicy` checks ([pnpm trustLockfile](https://pnpm.io/settings/dependency-resolution)). Selected 0.8.1; [v0.8.2](https://github.com/openclaw/clawpatch/releases/tag/v0.8.2) published 2026-10-01.
- **Status:** `decision` — explicitly accept with rationale, or remove both settings together.
- **Remove when:** the newest locked dependency is past 48 h; regenerate the pnpm dependency hash without `prePnpmInstall`.
- **Validate:** `.#clawpatch` build and CLI help/version plus affected full systems; updater in an isolated checkout must fail closed on a too-fresh lockfile. Re-review on any version, lock hash or upstream `minimumReleaseAge` change.

#### `whiteboard-bundled-electron`

Also covers audit ID `package-whiteboard-bundled-electron`.

- **Where:** `packages/whiteboard/default.nix` (binary DEB with bundled Electron 42.10.0).
- **Status:** `watch` — Electron 42 EOL **2026-10-20**. Latest upstream [v0.1.5](https://github.com/devdotfast/whiteboard/releases/tag/v0.1.5) (2026-09-28, = selected) pins 42.10.0 ([electron checksums](https://github.com/devdotfast/whiteboard/blob/v0.1.5/apps/review-desktop/code-oss/build/checksums/electron.txt)). On each manual review, warn before the date; after it, set `expired` and report.
- **Remove when:** update to a release whose packaged Electron major is supported (verify both source metadata and packaged runtime).
- **Validate:** `desktop`; runtime: desktop launch, CLI-to-desktop launch, one review/canvas flow.

## Deliberate choices (not upstream workarounds)

Not part of the manual upstream review. Revisit only when the named trigger
happens; do not remove them because upstream changed. Group names are stable.

| Group | Audit IDs | Where | Why it is not a workaround / revisit trigger |
| --- | --- | --- | --- |
| `channel-selection` | `master-channel-node26-selection`, `master-channel-factorio-experimental-selection`, `tuios-no-upstream-overlay-adapter` | `overlays/sgiath/default.nix` | Freshness preference (both currently equal root versions) and package-only input adapter. Revisit on freshness-policy change. |
| `release-pins` | `ordinary-root-release-pins`, `standard-input-follows-and-overlays`, `flake-binary-cache-configuration`, `comfyui-upstream-release-pin` | `flake.nix`, `scripts/update-inputs.sh` | Ordinary tagged/immutable input refs advanced by the release updater, per-input `nixpkgs` follows, module wiring, upstream overlays, and substituter/key preferences. Only `hyprland-glaze-release-freeze` is a pin workaround; Hyprland's nixpkgs not following root is tracked in `desktop-hyprland-mesa-abi`. Trust/cache changes are separate scope. |
| `bird-product` | `bird-native-linux-chromium-cookie-source`, `bird-standard-pnpm-recipe`, `hermes-bird-vesta-command-adapter` | `vendor/bird/src/lib/cookies.ts`, `vendor/bird/src/lib/chromium-cookies.ts`, `packages/bird/default.nix`, `modules/nixos/services/hermes-bird-vesta.sh` | Required read-only open-Chromium cookie reading (v11 keyring unsupported), normal pnpm recipe, digest command adapter. Credential/security changes need the security model. |
| `comfyui-product` | `comfyui-cache-registration`, `comfyui-json-repair`, `comfyui-prompt-enhancer-node`, `comfyui-rocm-attention-policy`, `comfyui-bundled-nodes-opt-out`, `comfyui-qwen-service-state`, `comfyui-qwen-workflow-seeding`, `comfyui-qwen-model-downloads` | `flake.nix` nixConfig, `overlays/comfyui/default.nix`, `modules/nixos/services/comfyui.nix`, `systems/x86_64-linux/ceres/qwen-image.nix`, `systems/x86_64-linux/ceres/qwen-image/` | Cache opt-in, enhancer dependency/node pin, ROCm attention policy, node surface, user-owned state, edit-preserving workflow seeding, verified model downloader. `json-repair` migrates with `comfyui-service-overlay-selection`. |
| `package-recipes` | `local-product-packaging`, `clawpatch-node-pnpm-toolchain`, `katrain-package-integration-details`, `openclaw-tauri-binary-layout`, `whiteboard-legacy-alias-removal`, `agent-orchestrator-bundled-abi-and-cli` (CLI exposure), `delta-authenticated-archive-packaging`, `relay-tester-manual-git-hash-refresh`, `quickshell-qtmultimedia-extension`, `quickshell-multimedia-and-qml-tooling` | `packages/`, `modules/home/desktop/quickshell.nix` | Ordinary reproducible packaging, binary relocation, QtMultimedia for video wallpaper. The bundled-Electron ABI is tracked in `agent-orchestrator-bundled-electron`. |
| `updater-and-maintenance` | `dnd5etools-split-image-release-policy`, `local-maintenance-and-installer-commands`, `development-shell-and-input-updater-policy`, `nebula-certificate-mobile-helpers` | `packages/dnd5etools/`, `packages/update/`, `packages/clear-cache/`, `packages/fix-images/`, `packages/live-install/`, `packages/burn-iso/`, `scripts/`, `shells/default/` | Local tools and update policy (dnd5etools images advanced manually by decision). |
| `security-policy` | `whiteboard-user-namespace-sandbox`, `grok-sandbox-off`, `installer-exported-keys-and-mobile-config`, `factorio-default-fetch-flow`, `factorio-headless-runtime-settings`, `matrix-livekit-runtime-turn-settings`, `normal-service-restart-and-auth-integrations` | `packages/whiteboard/default.nix`, `modules/home/agents/base.nix`, `packages/burn-iso/default.nix`, `scripts/nebula-mobile.sh`, `modules/nixos/gaming/role.nix`, `modules/nixos/services/factorio.nix`, `modules/nixos/services/matrix.nix`, agent/service modules | Intentional security-sensitive decisions: inert setuid helper removed (user-namespace sandbox, no `--no-sandbox`), explicit `GROK_SANDBOX=off`, exported installer keys, approved Factorio token handling, runtime credential serialization, service restart/auth boundaries. Change only by owner/security decision; never auto-remove. |
| `session-lifecycle` | `desktop-once-per-session-startup`, `desktop-launcher-independent-app-cgroups`, `docker-delayed-workstation-start`, `system-failure-watcher-product-policy`, `qml-local-reactivity-patterns`, `quickshell-icon-lookup-cost` | `modules/home/desktop/role.nix`, `modules/home/programs/chat.nix`, `modules/home/programs/email.nix`, `modules/home/desktop/quickshell/`, `modules/nixos/services/docker.nix`, `modules/home/agents/system-failure-watcher.sh` | Required once-per-session startup, app cgroup isolation, boot policy, watcher product rules, local QML patterns, launcher icon omission (owned by the proposed icon-lookup note). |
| `module-wiring` | `stylix-global-overlay-ownership`, `worktrunk-module-precedence`, `noctalia-v5-module-and-visual-contract`, `herdr-theme-parser-integration`, `theme-base16-dark-metadata`, `omp-desktop-wayland-feature` | `modules/nixos/desktop/stylix.nix`, `modules/home/desktop/stylix.nix`, `modules/home/terminal/worktrunk.nix`, `modules/home/terminal/herdr.nix`, `modules/home/desktop/noctalia.nix`, `themes/`, `modules/home/agents/omp.nix`, `flake.nix` module lists | Chosen module providers (HM worktrunk module disabled in favor of upstream's; HM Noctalia instead of the flake module), overlay ownership, theme data contract. Change only with the provider design. |
| `host-product-choices` | `host-hardware-and-build-resource-choices`, `networking-and-live-iso-forces`, `gaming-steam-lutris-prism-overrides`, `foundry-release-channel-override`, `hermes-feature-groups-and-user`, `gtk-chromium-wayland-preferences`, `other-package-selection-and-styling-preferences` | `modules/nixos/hardware/`, `systems/x86_64-linux/`, `modules/nixos/common/`, `modules/nixos/gaming/role.nix`, `modules/home/gaming/role.nix`, `modules/nixos/services/foundryvtt.nix`, `modules/nixos/services/hermes-agent.nix`, desktop modules | Hardware, network, game, licensing and appearance choices. |

### Stale comments (cleanup only, no workaround)

Fix together with the next change touching the file; behavior must not change.

- `flake.nix` Hyprland block says "Unpinned from v0.56.2" while pinned to v0.56.1 (see `hyprland-glaze-release-freeze`).
- `flake.nix` keeps a commented-out `nixpkgs-stable` input; no stable-channel workaround is active. Do not delete transitive lock nodes by name (`retired-stable-channel-comment`).
- `homes/x86_64-linux/sgiath@ceres/default.nix` says login default stays Noctalia; the evaluated default is `sgiath` (`noctalia-login-comment-stale`).
- `modules/home/terminal/herdr.nix` comment names Yoru; the parser reads `themes/sgiath.yaml` (`herdr-yoru-comment-stale`).
- `packages/katrain/default.nix` claims Kivy Python 3.14 support was merged; kivy#9225 is open.
- `packages/openclaw-desktop/default.nix` FIXME names only `/usr/bin/ssh`; the binary also tries `/bin/ssh`.
- `packages/AGENTS.md` lists obsolete package names and the old absolute Bird input.

## Resolved history

| ID | Resolved | Evidence |
| --- | --- | --- |
| `comfyui-retired-source-wheel-backport` | 4b9bbf78 | Local ComfyUI 0.37.0 + frontend/templates/docs/kitchen/aimdo backport removed; pinned comfyui-nix `versions.nix` supplies them. |
| `comfyui-retired-template-media-assets02-injection` | 4b9bbf78 | Pinned `nix/vendored-packages.nix` includes media-assets-02. |
| `comfyui-retired-rocm-launcher-library-order` | 4b9bbf78 | Pinned `nix/packages.nix:370-378` orders torch libs before the host driver dir; packaged torch import/GPU discovery verified 2026-10-01. |
| `minio-insecure-package-allowance` | 8134472e | Removed together with its host. |

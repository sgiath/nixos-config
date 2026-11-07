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

Baseline of this manual review: repository `082a34ed`, checked 2026-11-06.
Resolved through `flake.inputs`: root `nixpkgs` 1d060086, `home-manager`
2c0c1f01, `hyprland` acc1aa0b (v0.57.1; its nixpkgs 0bb2eedc), `comfyui`
58f91b00 (its nixpkgs dc5d91f8), `sops-nix` b18e01ce, `snowfall-lib`
6ee3542c, `nixpkgs-master` 164d29c0, `nixpkgs-ksa` 670a3617, `llm-agents`
baf92436 and `hermes-agent` 2bd378ed. Re-resolve them for each manual review;
never read bare lock nodes, which may name nested dependencies.

The **Review (2026-11-06)** entries give the current status and supersede older
upstream/selected-pin claims in each record. Historical **Exercised** evidence
keeps its original date. Every active record was accounted for; the six
security/credential-sensitive checks could not start because the required model
was unavailable, and the selected ISO was absent for geometry inspection. Those
seven records are retained as `unknown`. No workaround was removed, input
upgraded, package/system built or host deployed by this audit.

## Manual review

Invoke `/skill:review-upstream-workarounds` when you want fresh upstream checks.
The [project skill](.agents/skills/review-upstream-workarounds/SKILL.md) defines the
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
| [`zenpower-kbuild-module-install`](#zenpower-kbuild-module-install) | temporary fix | candidate | ceres, pallas, vesta |
| [`chatgpt-tpm2-tss-build-inputs`](#chatgpt-tpm2-tss-build-inputs) | temporary fix | candidate | desktop |
| [`cinny-desktop-gst-plugins`](#cinny-desktop-gst-plugins) | temporary fix | required | desktop |
| [`hermes-agent-exact-pin-relax`](#hermes-agent-exact-pin-relax) | compatibility | candidate | all |
| [`hermes-agent-node-patchelf`](#hermes-agent-node-patchelf) | temporary fix | candidate | vesta |
| [`hermes-agent-home-mode`](#hermes-agent-home-mode) | compatibility | unknown | vesta |
| [`snowfall-flake-utils-plus-deferred-config`](#snowfall-flake-utils-plus-deferred-config) | vendored fork | required | all |
| [`hyprland-glaze-release-freeze`](#hyprland-glaze-release-freeze) | input pin | candidate | desktop |
| [`ksa-unmerged-nixpkgs-package`](#ksa-unmerged-nixpkgs-package) | input fork | required | ceres |
| [`bird-unavailable-upstream-vendoring`](#bird-unavailable-upstream-vendoring) | vendored source | unknown | ceres, vesta |
| [`comfyui-rocm-int8-probe`](#comfyui-rocm-int8-probe) | temporary fix | required | ceres, juno1 |
| [`comfyui-python-package-set`](#comfyui-python-package-set) | compatibility | required | ceres, juno1 |
| [`comfyui-open-clip-broken-allowance`](#comfyui-open-clip-broken-allowance) | compatibility | candidate | ceres |
| [`comfyui-service-overlay-selection`](#comfyui-service-overlay-selection) | compatibility | required | ceres |
| [`comfyui-rocm-platform-guard`](#comfyui-rocm-platform-guard) | compatibility | required | ceres, juno1 |
| [`comfyui-qwen-memory-policy`](#comfyui-qwen-memory-policy) | compatibility | required | ceres |
| [`desktop-hyprland-mesa-abi`](#desktop-hyprland-mesa-abi) | ABI | candidate | desktop |
| [`portal-qt-theme-isolation`](#portal-qt-theme-isolation) | compatibility | candidate | desktop |
| [`legacy-wlroots-session-flags`](#legacy-wlroots-session-flags) | compatibility | unverified | desktop |
| [`satty-floating-hack`](#satty-floating-hack) | compatibility | required | desktop |
| [`quickshell-store-theme-restart`](#quickshell-store-theme-restart) | compatibility | unverified | desktop |
| [`quickshell-hyprland-workspace-address`](#quickshell-hyprland-workspace-address) | compatibility | required | desktop |
| [`hex-model-service-selection`](#hex-model-service-selection) | temporary fix | required | desktop |
| [`preview-share-picker-hyprland-057-ipc`](#preview-share-picker-hyprland-057-ipc) | temporary fix | required | desktop |
| [`gaming-gtk2-broken-allowance`](#gaming-gtk2-broken-allowance) | compatibility | required | ceres |
| [`tmux-sessionizer-session-target`](#tmux-sessionizer-session-target) | temporary fix | candidate | all |
| [`pihole-first-run-setup-retry`](#pihole-first-run-setup-retry) | temporary fix | required | vesta |
| [`searx-json-secret-interpolation`](#searx-json-secret-interpolation) | temporary fix | unknown | vesta |
| [`executor-state-ownership-migration`](#executor-state-ownership-migration) | data migration | unknown | vesta |
| [`executor-registry-image-version-selection`](#executor-registry-image-version-selection) | updater constraint | required | vesta |
| [`ollama-rocm-gfx-override-dormant`](#ollama-rocm-gfx-override-dormant) | compatibility | dormant | ceres |
| [`katrain-kivy-python-api`](#katrain-kivy-python-api) | compatibility | required | ceres |
| [`katrain-kivy-cython-long`](#katrain-kivy-cython-long) | temporary fix | required | ceres |
| [`katrain-chardet-major-version`](#katrain-chardet-major-version) | compatibility | required | ceres |
| [`katrain-bundled-katago-appimage`](#katrain-bundled-katago-appimage) | compatibility | required | ceres |
| [`katrain-opencl-test-exclusion`](#katrain-opencl-test-exclusion) | test exception | required | ceres |
| [`whiteboard-angle-runpath`](#whiteboard-angle-runpath) | compatibility | required | desktop |
| [`whiteboard-cli-desktop-environment`](#whiteboard-cli-desktop-environment) | compatibility | required | desktop |
| [`openclaw-desktop-deep-link-wrapper`](#openclaw-desktop-deep-link-wrapper) | temporary fix | required | desktop |
| [`openclaw-desktop-remote-ssh-limitation`](#openclaw-desktop-remote-ssh-limitation) | known limitation | required | desktop |
| [`openclaw-desktop-asset-aware-updater`](#openclaw-desktop-asset-aware-updater) | updater constraint | required | desktop |
| [`nak-network-check-disable`](#nak-network-check-disable) | test exception | required | package only (not installed) |
| [`davinci-resolve-mcp-sdk-version`](#davinci-resolve-mcp-sdk-version) | compatibility | required | ceres |
| [`t3code-nightly-sea-patchelf`](#t3code-nightly-sea-patchelf) | temporary fix | required | ceres, vesta |
| [`cross-architecture-nixos-rebuild-no-reexec`](#cross-architecture-nixos-rebuild-no-reexec) | compatibility | candidate | ceres, juno1 |
| [`burn-iso-hybrid-mbr-key-partition`](#burn-iso-hybrid-mbr-key-partition) | compatibility | unknown | iso |
| [`dgx-spark-nvidia-kernel-cve-2026-98432`](#dgx-spark-nvidia-kernel-cve-2026-98432) | security backport | unknown | juno1 |
| [`whiteboard-bundled-electron`](#whiteboard-bundled-electron) | security exception | unknown | desktop |

### Flake inputs, overlays and vendoring

#### `zenpower-kbuild-module-install`

- **Review (2026-11-06):** `candidate`. Selected root nixpkgs `1d060086` contains [976984ad](https://github.com/NixOS/nixpkgs/commit/976984ad4730) (`compare` to pin: ahead 9955, behind 0); its [zenpower package](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/pkgs/os-specific/linux/zenpower/default.nix) now supplies `kernelModuleMakeFlags`, `installTargets = [ "modules_install" ]`, the kernel build directory and `M=$(PWD)`. Full Ceres selection is zenpower5 `0.5.0-unstable-2026-01-07` (zenpower5 source `66871d8e`). The local extension duplicates the selected fix. [Issue #575192](https://github.com/NixOS/nixpkgs/issues/575192) remains open, so issue state alone is misleading. Removal still needs `ceres`, `pallas`, `vesta` builds without the extension, output/module-tree certificate proof, and booted `sensors` evidence; none was run by this audit.

- **Where:** `overlays/sgiath/default.nix` (`kernelPackagesExtensions` override of `zenpower`).
- **Why:** since [NixOS/nixpkgs#571181](https://github.com/NixOS/nixpkgs/pull/571181) Kbuild signs every module with kmodigest during `modules_install` and writes `<module>.ko.cer` next to it, and `aggregateModules` concatenates the certificates of all external modules into `modules.cer`. zenpower copies `zenpower.ko` by hand, so there is no certificate and the `linux-*-modules` build fails with `cat: kernel/drivers/hwmon/zenpower/zenpower.ko.cer: No such file or directory`. The override adds `kernelModuleMakeFlags` and installs through the kernel's `modules_install` (same path, stripped, `DEPMOD=true`), which also compresses the module.
- **Upstream:** [NixOS/nixpkgs#575192](https://github.com/NixOS/nixpkgs/issues/575192) open; the maintainer comment there describes this exact fix for zenpower. No zenpower PR yet (checked 2026-10-20); sibling fixes are open for `system76`, `framework-laptop-kmod` and `lenovo-legion-module`.
- **Selected pin:** root nixpkgs 09063bd1 has kmodigest signing and the certificate merge in `pkgs/os-specific/linux/kmod/aggregator.nix`; `pkgs/os-specific/linux/zenpower/default.nix` still has the hand-written `installPhase` without `kernelModuleMakeFlags`.
- **Remove when:** the selected zenpower package installs through `modules_install` and its output has `zenpower.ko.cer`. Remove the whole `kernelPackagesExtensions` entry.
- **Validate:** `ceres`, `pallas`, `vesta`; also `nix build .#nixosConfigurations.<host>.config.system.modulesTree` and check that `modules.dep` lists `zenpower.ko.xz` and `modules.cer` ends with `zenpower.ko.cer`. Runtime: `sensors` shows `zenpower-pci-*` after boot.
- **Exercised (2026-10-20):** without the override the Ceres modules tree failed with the error above; with it zenpower builds as `zenpower.ko.xz` plus a 260-byte `zenpower.ko.cer`, the Ceres modules tree builds, `modules.cer` is the kernel certificates followed by exactly that certificate, and `modinfo` reports the same PKCS#7 signature and vermagic as in-tree `k10temp`. The Vesta modules tree also builds with the merged certificate. On Pallas zenpower now builds with its certificate, but the modules tree still fails on the openrazer modules, which have the same problem.

#### `chatgpt-tpm2-tss-build-inputs`

- **Review (2026-11-06):** `candidate`. Selected llm-agents `baf92436` equals live main and contains [a5c70bf1](https://github.com/numtide/llm-agents.nix/commit/a5c70bf1c91c) (`compare` to pin: ahead 1173, behind 0). Its [unwrapped recipe](https://github.com/numtide/llm-agents.nix/blob/baf924369e8d5ec02af1eab444db411d6fed1e5e/packages/chatgpt/unwrapped.nix) directly includes both `openssl` and `tpm2-tss` in Linux `buildInputs`. Full Ceres selects ChatGPT `26.1029.61003`, against root nixpkgs `1d060086`. The dependency gate is met; desktop builds without the duplicate inputs, native-module `ldd`, and Remote Control pairing remain unrun. Remove only the ChatGPT override, preserving other active `llm-agents` overrides.

- **Where:** `overlays/sgiath/default.nix` (`llm-agents.chatgpt` with `chatgpt-unwrapped` overridden).
- **Why:** since 26.1013.40934 ChatGPT ships `resources/native/remote-control-device-key.node`, which links `libtss2-esys.so.0`, `libtss2-mu.so.0`, `libtss2-tcti-device.so.0` and `libcrypto.so.3`. llm-agents doesn't list tpm2-tss or OpenSSL in `chatgpt-unwrapped`; auto-formatelf only found them by following the RUNPATH of `libnss_myhostname.so.2`/`libnss_systemd.so.2` in systemd 261.3. systemd 262 libraries don't carry that RUNPATH anymore, so with our nixpkgs the build fails with `auto-formatelf: libtss2-esys.so.0 not found`. The override adds `openssl` and `tpm2-tss` to `buildInputs`, nothing else.
- **Upstream:** no issue or PR in numtide/llm-agents.nix; `packages/chatgpt/unwrapped.nix` on main c31c0e89 still lists neither (checked 2026-10-20). Upstream's own build of 26.1013.40934 is cached because its nixpkgs still has systemd 261.3.
- **Selected pin:** llm-agents 6831eed9 through `overlays.shared-nixpkgs`, so `chatgpt-unwrapped` builds against root nixpkgs 09063bd1 with systemd 262.
- **Remove when:** the selected `chatgpt-unwrapped` has tpm2-tss and OpenSSL in its own inputs, or ChatGPT stops shipping the module. Remove only the ChatGPT override, preserving unrelated `llm-agents` overrides.
- **Validate:** `ceres`, `pallas`; `ldd lib/chatgpt/resources/native/remote-control-device-key.node` in `.llm-agents.chatgpt.unwrapped` has no `not found`. Runtime: ChatGPT Remote Control still pairs the device.
- **Exercised (2026-10-20):** without the override the full Ceres build failed in `chatgpt-unwrapped` with the error above. With it `chatgpt-unwrapped` and `chatgpt` build, the module RUNPATH points at tpm2-tss 4.2.0, OpenSSL 3.5.9 and gcc-lib, `ldd` resolves everything and the bundled Node loads the module (`getDeviceKeyPublic`, `signDeviceKey`). Remote Control itself wasn't tried.

#### `cinny-desktop-gst-plugins`

- **Review (2026-11-06):** `required`. [nixpkgs #578827](https://github.com/NixOS/nixpkgs/pull/578827) merged as `e56cb3d6` on 2026-10-29, but both live master and [selected root `1d060086`](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/pkgs/by-name/ci/cinny-desktop/package.nix) still list only GStreamer and Base, without Good or Bad. Full Ceres now selects Cinny `4.12.8`; Good and Bad in its evaluated inputs come from the local overlay. The release update does not satisfy the removal gate.

- **Where:** `overlays/sgiath/default.nix` (`cinny-desktop` adds `gst_all_1.gst-plugins-good` and `gst_all_1.gst-plugins-bad` to `buildInputs`; `wrapGAppsHook3` puts them on the launcher's `GST_PLUGIN_SYSTEM_PATH_1_0`, so the desktop entry and the `cinny-desktop` user service in `modules/home/programs/chat.nix` both get them).
- **Why:** nixpkgs gives Cinny only `gstreamer` and `gst-plugins-base`. WebKitGTK 2.54.1 aborts the web process in `MediaPlayerPrivateGStreamer::createAudioSink` when audio plays (`GStreamer element autoaudiosink not found`), which crashed Cinny on Ceres. `autoaudiosink` is in Good; playback then still fails without Bad's `fakevideosink` and WebVTT encoder. gst-libav was not needed for the reproduction and is not added.
- **Upstream:** no nixpkgs issue or PR (searched 2026-10-29). [NixOS/nixpkgs#549174](https://github.com/NixOS/nixpkgs/pull/549174) added only `gstreamer` and `gst-plugins-base`; open update [NixOS/nixpkgs#578827](https://github.com/NixOS/nixpkgs/pull/578827) (4.12.8) does not touch GStreamer inputs, and `pkgs/by-name/ci/cinny-desktop/package.nix` on master still lists only base.
- **Selected pin:** root nixpkgs 31ecbaca, `cinny-desktop` 4.12.7 with WebKitGTK 2.54.1 and GStreamer 1.28.7; its `buildInputs` have no Good or Bad plugins.
- **Remove when:** the selected `cinny-desktop` puts Good and Bad on its launcher's plugin path itself (or WebKit no longer needs them for audio playback). Remove the overlay attr only.
- **Validate:** `desktop`; the launcher's embedded `GST_PLUGIN_SYSTEM_PATH_1_0` lists gst-plugins-good and gst-plugins-bad. Runtime: Cinny plays an audio message without the web process crashing and the journal has no `autoaudiosink not found`.
- **Exercised (2026-10-29):** a throwaway harness loading a silent WAV `<audio>` in the same WebKitGTK library crashed the web process with the natural log line under the unfixed plugin path, and reached `ended` (PASS) under the fixed launcher's plugin path. Good alone avoided the crash but timed out without `fakevideosink`. Full Ceres and Pallas toplevel builds passed. Activated the Ceres system and reopened Cinny on the fixed package; the same harness reached `ended` with the running app's actual plugin environment, and the app stayed running with no new audio errors. No login or chat data was changed.

#### `hermes-agent-exact-pin-relax`

- **Review (2026-11-06):** `candidate`. Selected llm-agents `baf92436` equals live main; its [Hermes recipe](https://github.com/numtide/llm-agents.nix/blob/baf924369e8d5ec02af1eab444db411d6fed1e5e/packages/hermes-agent/package.nix#L637-L660) now relaxes both `markdown` and `prompt_toolkit` itself. Full Ceres selects llm-agents Hermes `0.22.7` (source tag commit `b200f5bc`), and the evaluated relaxation list includes each twice because of the local override. The dependency gate is met; `all` profile builds, package checks and interactive Markdown rendering without the override remain unrun. Remove the local Hermes-agent/Desktop overrides together while preserving unrelated `llm-agents` overrides.

- **Where:** `overlays/sgiath/default.nix` (`llm-agents.hermes-agent` adds `prompt_toolkit` and `markdown` to `pythonRelaxDeps`, spelled as in the wheel metadata because the relax hook matches names literally (case-insensitive only); `llm-agents.hermes-desktop` gets the overridden `hermes-agent`).
- **Why:** Hermes 0.22.2 pins `prompt_toolkit==3.0.52` and `Markdown==3.10.2` in `pyproject.toml`. Root nixpkgs 09063bd1 has prompt-toolkit 3.0.53 and Markdown 3.10.3, so `pythonRuntimeDepsCheck` fails with `prompt-toolkit==3.0.52 not satisfied by version 3.0.53` and `markdown==3.10.2 not satisfied by version 3.10.3`. llm-agents already relaxes the other `==` pins nixpkgs moved past (`rich`, `pillow`, `croniter`, `exa-py`); this adds the same for these two patch releases.
- **Upstream:** no issue or PR in numtide/llm-agents.nix; `packages/hermes-agent/package.nix` on main c31c0e89 has the same `pythonRelaxDeps` (checked 2026-10-20). Upstream's own build passes because its nixpkgs f20cd90e still has the pinned versions.
- **Selected pin:** llm-agents 6831eed9 through `overlays.shared-nixpkgs`, so `hermes-agent` builds against root nixpkgs 09063bd1.
- **Remove when:** the selected `hermes-agent` relaxes or accepts both versions itself. Remove both Hermes-specific attrs, preserving unrelated `llm-agents` overrides; keep `hermes-desktop` only while `hermes-agent` is overridden.
- **Validate:** `ceres`, `pallas`, `vesta`, `juno1`; `nix build --no-link .#nixosConfigurations.ceres.pkgs.llm-agents.hermes-agent .#nixosConfigurations.ceres.pkgs.llm-agents.hermes-desktop` (runs its imports and version checks). Runtime: `hermes` starts its interactive CLI and Markdown formatting still renders.
- **Exercised (2026-10-20):** without the override the full Ceres build failed in `hermes-agent` with the errors above. With it `hermes-agent` and `hermes-desktop` build (import, version and install checks pass), `hermes --version` runs, its Python env imports `cli` with prompt_toolkit 3.0.53 and renders Markdown with 3.10.3, and the full Ceres build passes. The interactive CLI wasn't started.

#### `hermes-agent-node-patchelf`

- **Review (2026-11-06):** `candidate`. Full Vesta selects Hermes input `2bd378ed` (`v0.23.0`), whose [pm-packages.nix](https://github.com/NousResearch/hermes-agent/blob/2bd378ed1b8d6bf2192cb26e0a55ff3091e6bd19/nix/pm-packages.nix#L55-L88) already backports [patchelf #672](https://github.com/NixOS/patchelf/pull/672) (`59acc3d9`, merged as `3e996dbe`) and puts that patched patchelf first in upstream Node inputs. Live Hermes main `b2e4ded5` retains it. The selected Node `26.12.1` derivation has local patchelf `0.15.5` followed by upstream patched `0.19.2`; derivation inspection confirms the latter contains `patchelf-fix-executable-header-load-overlap.patch`. Root `1d060086` still selects plain `0.19.2`, which compares behind the merge by 2 commits. Latest patchelf [0.19.3](https://github.com/NixOS/patchelf/releases/tag/0.19.3) contains the fix (ahead 21, behind 0), but that release is not selected. Upstream's backport makes the old local pin redundant in source; removing it still needs the unoverridden `node --version`, non-overlapping ELF mapping, Vesta build and dashboard TUI runtime checks. The evaluated Hermes wrapper reports version `0.0.0` because its Nix input metadata is not passed as a version; do not confuse that with its resolved input tag.

- **Where:** `overlays/sgiath/default.nix` (`hermes-agent`: `pmPackages.node` gets patchelf 0.15.5 first in `nativeBuildInputs`, so its `autoPatchelfHook` uses it).
- **Why:** Hermes builds its TUI, web UI and wrapper on the upstream `node-v26.12.1-linux-x64` binary pinned in `pm/lock.json`, fixed up by `autoPatchelfHook`. auto-patchelf runs `--set-interpreter` and then `--set-rpath`; with patchelf 0.18+ that leaves `.dynamic` in a new RW `PT_LOAD` at `0x3ff000`-`0x80c358` which the next read-only `PT_LOAD` (from `0x4002fc`) overlaps. The read-only mapping wins, ld.so dies writing `DT_DEBUG`, and every `node`/`npm` call exits 139. `hermes-tui` fails first, in `npmConfigHook` at `npm config set offline true`, which breaks the service package and the Vesta toplevel. Same failure class as `t3code-nightly-sea-patchelf`.
- **Upstream:** [NixOS/patchelf#674](https://github.com/NixOS/patchelf/issues/674) (interpreter before RPATH breaks the binary) open; [NixOS/patchelf#672](https://github.com/NixOS/patchelf/pull/672) (overlapping LOAD after header rewrites) merged 2026-10-20 as 3e996dbe, unreleased (latest 0.19.2); [#668](https://github.com/NixOS/patchelf/pull/668) open. nixpkgs works around it per package ([#576879](https://github.com/NixOS/nixpkgs/pull/576879) old patchelf, [#576397](https://github.com/NixOS/nixpkgs/pull/576397) RPATH first). Hermes v0.22.5 itself builds against its own nixpkgs 0954f7ee with patchelf 0.15.2 (checked 2026-10-23).
- **Selected pin:** hermes-agent v0.22.5 (bf0203a7) follows root nixpkgs 02c087f3, whose `patchelf` is 0.19.2 and `patchelfUnstable` 0.18.0-unstable-2025-08-13.
- **Remove when:** the nixpkgs `patchelf` selected for Hermes contains patchelf#672 (or Hermes stops patching the pinned node), and `node --version` from `.#nixosConfigurations.vesta.config.services.hermes-agent.package.hermesNpmLib.nodejs` runs without the override. Remove the whole `hermes-agent` attr.
- **Validate:** `vesta`; `nix build --no-link .#nixosConfigurations.vesta.config.services.hermes-agent.package` (the TUI build runs npm on the patched node); `readelf -lW` on that node shows `DYNAMIC` inside a RW `LOAD` that no other `LOAD` overlaps. Runtime: `hermes-dashboard` serves the TUI (`HERMES_DASHBOARD_TUI=1`).
- **Exercised (2026-10-23):** without the override `hermes-tui` (i9wi8laf) failed with `Segmentation fault (core dumped) npm config set offline true`, and the pinned node segfaulted on `--version`. Patching the pristine tarball by hand with only the patchelf version or order changed: interpreter then RPATH segfaults with 0.18.0-unstable and 0.19.2 and runs with 0.15.2 and patchelf master 3e996dbe; RPATH then interpreter, or either change alone, runs with 0.19.2. With the override node runs `--version`, npm 12.0.2 runs on it, `DYNAMIC` sits in a one-page RW `LOAD` at `0x3ff000` ending where the next `LOAD` starts, the Hermes service package builds (TUI, web, wrapper), `hermes --version` runs on `HERMES_NODE`, and the full Vesta toplevel builds. The pinned uv, ffmpeg and ripgrep run without the override. The dashboard TUI wasn't started on Vesta.

#### `snowfall-flake-utils-plus-deferred-config`

- **Review (2026-11-06):** `required`. Resolved Snowfall input `6ee3542c` still equals [live main](https://github.com/snowfallorg/lib/commit/6ee3542cb459ca4b038cfe50ceb8797f05cdabad) and selects the local `flake-utils-plus-fixed` wrapper based on `3542fe91`. Live flake-utils-plus [master `a00f6f51`](https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/a00f6f51907b5c74d2fde086b10b19d446d15717/lib/mkFlake.nix#L113-L155) still pre-evaluates `hostConfig` and forces `nixpkgs.config = {}`. [#163](https://github.com/gytis-ivaskevicius/flake-utils-plus/pull/163) remains open/unmerged at head `10d81075`, whose implementation still injects `nixpkgs.pkgs = selectedNixpkgs`. The selected local wrapper still supplies deferred configuration, overlay metadata and `nix.settings.nix-path`; the equivalence gate is not met.

- **Where:** `flake.nix` (`flake-utils-plus-fixed` input; `snowfall-lib.inputs.flake-utils-plus.follows`), `vendor/flake-utils-plus-fixed/flake.nix`, `vendor/flake-utils-plus-fixed/lib/mkFlake.nix`, `vendor/flake-utils-plus-fixed/lib/options.nix`.
- **Why:** upstream `mkFlake` pre-evaluates `hostConfig` and forces `nixpkgs.config = mkForce {}`, breaking host `nixpkgs.config`. The wrapper (based on upstream 3542fe91) passes channel config/overlays as NixOS module definitions, keeps raw channel data in `__flakeUtilsPlus`, and migrates `nix.nixPath` to `nix.settings.nix-path`.
- **Upstream:** [flake-utils-plus#162](https://github.com/gytis-ivaskevicius/flake-utils-plus/issues/162); [#163](https://github.com/gytis-ivaskevicius/flake-utils-plus/pull/163) open, unmerged (head 10d81075), and **not equivalent**: it injects external `nixpkgs.pkgs` and documents that host `nixpkgs.config` still fails. Master a00f6f51 still has the eager evaluation. Snowfall main is the pinned 6ee3542c ([snowfallorg/lib#173](https://github.com/snowfallorg/lib/issues/173), maintainer call).
- **Remove when:** a selected upstream supports host `nixpkgs.config`, channel overlays/config, registry/input linking and `nix.settings.nix-path`. Then retarget the follows and delete the vendor tree. Merging #163 alone is insufficient; do not move host package policy into a new workaround to accommodate it.
- **Validate:** `all`; runtime (VM/host): Nix registry, input symlinks, `NIX_PATH`, representative overlaid packages.
- **Origin:** 26bbf25b (2026-08-09).

#### `hyprland-glaze-release-freeze`

- **Review (2026-11-06):** `candidate`. The registry's v0.56.1 freeze and stale-comment description no longer matches source: `flake.nix` now selects [v0.57.1 `acc1aa0b`](https://github.com/hyprwm/Hyprland/tree/acc1aa0bfd4bd575dcb0f76c35ccf12b660a1ab9), the current latest release, and the freeze marker/comment is absent from `scripts/update-inputs.sh`/`flake.nix`. Comparing [glaze fix `91f29f23` to the pin](https://github.com/hyprwm/Hyprland/compare/91f29f23bb691462f8aa6171b964069aebc37910...acc1aa0bfd4bd575dcb0f76c35ccf12b660a1ab9) gives ahead 291, behind 0. Pinned `CMakeLists.txt` has unrestricted `find_package(glaze QUIET)`. Full Ceres selection is `0.57.1+date=2026-11-03_acc1aa0`; root glaze is `9.0.0` (Hyprland uses its own resolved package set). The original pin workaround is already absent; keep the record pending reconciliation rather than claiming a verified removal. Audit did not establish desktop full-build and login/acceleration/portal/plugin runtime proof for this current pin.

- **Where:** `flake.nix` (`hyprland.url = github:hyprwm/Hyprland/v0.56.1`, comment block above it; `hyprland-plugins` follows it), `scripts/update-inputs.sh` (the `# pin to v0.56.1` marker freezes the updater).
- **Why:** v0.56.x `CMakeLists.txt:133` requires `find_package(glaze 7...<8 QUIET)` and falls back to network `FetchContent`; root nixpkgs ships glaze 8.4.0. Why v0.56.1 rather than main was chosen (87644f14) is undocumented; do not claim v0.56.1 solves glaze 8.
- **Upstream:** [Hyprland 91f29f23](https://github.com/hyprwm/Hyprland/commit/91f29f23bb691462f8aa6171b964069aebc37910) removed the limit on main (2026-08-04). [Latest release](https://github.com/hyprwm/Hyprland/releases/latest) v0.56.2 does not contain it.
- **Stale comment:** `flake.nix` says "Unpinned from v0.56.2"; the input is pinned to v0.56.1. Fix the prose in the same change that next touches this pin.
- **Side finding:** evaluating the raw `nixosConfigurations.ceres.pkgs.hyprland.version` failed on missing `hyprland-guiutils` (the `default` overlay omits the dependency overlays). Not shown to affect the full systems.
- **Remove when:** a release whose actual source accepts the selected glaze (or ships a sandbox-safe dependency) exists; verify full Hyprland dependency overlay wiring, keep Mesa/portal/plugins matched, then update the pin and the updater marker.
- **Validate:** `desktop`; runtime: log in, `hyprctl version`, displays, acceleration, screen sharing, plugins.

#### `ksa-unmerged-nixpkgs-package`

- **Review (2026-11-06):** `required`. [nixpkgs #492242](https://github.com/NixOS/nixpkgs/pull/492242) remains open/unmerged, with head `670a3617` equal to resolved `nixpkgs-ksa`. Root `1d060086` still has no KSA package source. Full Ceres selects the fork's KSA `2026.5.7.4397`; the root-package availability gate is not met.

- **Where:** `flake.nix` (`nixpkgs-ksa`), `overlays/sgiath/default.nix` (`pkgs-ksa`, `ksa`), consumer `modules/home/gaming/role.nix`.
- **Why:** Kitten Space Agency is not in root nixpkgs; the fork branch packages 2026.5.7.4397.
- **Upstream:** [NixOS/nixpkgs#492242](https://github.com/NixOS/nixpkgs/pull/492242) open, unmerged; head equals the pinned 670a3617.
- **Remove when:** root nixpkgs has `ksa` at the needed version with equivalent runtime deps; remove input, import and overlay attr together. Keep it gaming-only (not on Pallas).
- **Validate:** `ceres` plus `.#nixosConfigurations.ceres.pkgs.ksa`; runtime: game reaches playable state.

#### `bird-unavailable-upstream-vendoring`

- **Review (2026-11-06):** `unknown`. The required security/credential-handling delegate could not start: orchestrator capabilities advertised no matching model, and delegate_task with provider opencode/model openai-codex/gpt-daybreak-blue-latest returned model_unavailable. No substitute review was performed. The previously recorded [steipete/bird](https://github.com/steipete/bird) 404 and the vendored 0.8.0/native-cookie behavior remain historical evidence; live availability and equivalence were not revalidated. Retain the vendor tree and deliberate bird-product decisions.

- **Where:** `vendor/bird/`, `packages/bird/default.nix` (builds from `vendor/bird`).
- **Why:** upstream is unreachable; the vendored 0.8.0 tree is also locally modified (native Linux Chromium cookie source, dependency refresh, e.g. d9fce644).
- **Upstream:** [steipete/bird](https://github.com/steipete/bird) returned HTTP 404 from the API and the web (deleted vs private unknown).
- **Remove when:** a fetchable immutable upstream preserves all current CLI behavior and the native open-Chromium cookie reading (see deliberate group `bird-product`). Compare against the local tree, not the version string.
- **Validate:** `ceres`, `vesta` plus `pkgs.sgiath.bird`; runtime: `bird --help`; an authenticated read only with explicit authorization, never printing credentials.

### ComfyUI (Ceres)

Common runtime check for every ComfyUI record: `systemctl show comfyui.service -p ActiveState -p ExecStart`, `GET http://127.0.0.1:8188/system_stats` and `/object_info`, then run both seeded Qwen workflows (`int8.json`, `int8-enhanced.json`) to completion. Eval/import success is not image-generation proof. Overlay/platform changes also need `juno1` to prove the x86-only code stays lazy.

#### `comfyui-rocm-int8-probe`

- **Review (2026-11-06):** `required`. Resolved comfyui-nix `58f91b00` still equals [live main/latest v0.37.0-r1](https://github.com/utensils/comfyui-nix/tree/58f91b001c99a97df46b7be8d58b08f01cb8f6ff). Full Ceres service selects ComfyUI `0.37.0`, fetched revision `73c9bad4`; its selected patched source `/nix/store/pr50d0r8spnyz9gr5xm213rxbyk7hqgz-source-patched` contains the local cached ROCm `_int_mm` probe. The [unpatched pinned function](https://github.com/Comfy-Org/ComfyUI/blob/73c9bad4d21e7addbe1d13bc92eee0f1431b017d/comfy/model_management.py#L2049-L2068) and both [latest v0.44.0](https://github.com/Comfy-Org/ComfyUI/blob/v0.44.0/comfy/model_management.py#L2101-L2125) and [live master `63e5bf59`](https://github.com/Comfy-Org/ComfyUI/blob/63e5bf594339f676b4b15e072529873e3448409e/comfy/model_management.py#L2154-L2178) still lack that probe. New upstream CPU exclusions are not equivalent. The selected service Python closure still has the torch `2.10.0+rocm7.1` wheel; no new gfx1030 GEMM or workflow execution was authorized/run.

- **Where:** `overlays/comfyui/default.nix` (`applyPatches` override), `overlays/comfyui/rocm-int8-compute.patch`.
- **Why:** PyTorch 2.10.0+rocm7.1 lacks the hipBLASLt gfx1030 Tensile library. The patch probes `torch._int_mm` once per AMD device in `supports_int8_compute`, caching `False` on `RuntimeError` so ComfyUI uses its existing dequantized full-precision path; CPU and non-AMD paths are not probed.
- **Upstream:** `supports_int8_compute` has no ROCm probe in ComfyUI 0.37.0 ([73c9bad4](https://github.com/Comfy-Org/ComfyUI/blob/73c9bad4d21e7addbe1d13bc92eee0f1431b017d/comfy/model_management.py#L2049-L2065)), 0.38.0, latest release 0.39.0 or master [0df64eb2](https://github.com/Comfy-Org/ComfyUI/blob/0df64eb242b7c5759c3e86afd5d1846d923b1033/comfy/model_management.py#L2082-L2098) (excludes only MPS, XPU, DirectML, ixuca). [#16130](https://github.com/Comfy-Org/ComfyUI/pull/16130) and [#16285](https://github.com/Comfy-Org/ComfyUI/pull/16285) are related, not equivalent. No ROCm `_int_mm` issue found (search absence is not proof). comfyui-nix main = latest release = pin 58f91b00 (v0.37.0-r1).
- **Remove when:** the selected comfyui-nix package contains an equivalent capability check, or its selected ROCm wheel runs INT8 GEMM on gfx1030. Inspect the fetched/patched source and actual wheel. Cut over the package construction, service selection and `json-repair` together.
- **Validate:** `ceres` + `juno1`; runtime: with packaged Python, `torch._int_mm` and `supports_int8_compute` for `cuda:0` and `cpu`, then both workflows without HIPBLAS errors.
- **Exercised (2026-10-01):** deployed packaged Python reported gfx1030; native probe hit missing `TensileLibrary_lazy_gfx1030.dat`/`HIPBLAS_STATUS_INVALID_VALUE`; GPU `False` (cached), CPU `True`. No image generated.

#### `comfyui-python-package-set`

- **Review (2026-11-06):** `required`. comfyui-nix `58f91b00` still pins nixpkgs `dc5d91f8` through `flake.inputs`; [its current Python overrides](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/nix/python-overrides.nix) remain paired with that scope. Full Ceres service resolves Python `3.12.14`, torch `2.10.0+rocm7.1`, torchvision `0.25.0`, torchaudio `2.10.0`, and json-repair `0.55.2` from the selected `pythonRuntime.paths`. [#81](https://github.com/utensils/comfyui-nix/issues/81) remains closed, but no compatible root-scope GPU-stack proof or removal of the needed local INT8 patch exists. Retain the private construction.

- **Where:** `overlays/comfyui/default.nix` (`import comfyui-nix.inputs.nixpkgs`, upstream `versions.nix`, `python-overrides.nix`).
- **Why:** builds with comfyui-nix's own nixpkgs (dc5d91f8), not root nixpkgs, so upstream Python overrides (Python 3.12, torch 2.10.0+rocm7.1) still match and unchanged derivations share store paths.
- **Upstream:** [python-overrides.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/nix/python-overrides.nix); [comfyui-nix#81](https://github.com/utensils/comfyui-nix/issues/81) closed 2026-08-14, which does not prove root-nixpkgs compatibility.
- **Remove when:** the local source patch no longer needs a private package construction (prefer upstream package + `withExtraPythonPackages`), or root pkgs is proven compatible for the full GPU Python scope with no duplicate torch stack. Keep `json-repair` and ROCm library order.
- **Validate:** `ceres` + `juno1`; runtime: import torch/torchvision/torchaudio/json_repair from the service Python, ROCm device visible, both workflows.

#### `comfyui-open-clip-broken-allowance`

- **Review (2026-11-06):** `candidate`. The selected nested nixpkgs [dc5d91f8 open-clip-torch recipe](https://github.com/NixOS/nixpkgs/blob/dc5d91f840324650bac8c379428c7037a416959a/pkgs/development/python-modules/open-clip-torch/default.nix) has no `meta.broken` declaration. Full Ceres's actual selected service Python paths include open-clip-torch `3.3.0` with `meta.broken = false`. comfyui-nix [58f91b00 still carries its allowance](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L177-L184), but that is not evidence this selected Linux package needs one. The local broken-package predicate appears inert; its removal still needs the Ceres full build without it, service-Python `import open_clip`, and both Qwen workflows. No package/system build or runtime proof was run here.

- **Where:** `overlays/comfyui/default.nix` (`allowBrokenPredicate` for `open-clip-torch`).
- **Why:** the private package set marks `open-clip-torch` broken; this mirrors upstream comfyui-nix ([flake.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L177-L184), tests disabled in [python-overrides.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/nix/python-overrides.nix#L954-L959)). Not an insecure-package exemption.
- **Remove when:** the selected nixpkgs/Python scope builds `open-clip-torch` without the predicate, or the closure no longer contains it. Upstream dropping its own exception is a prompt to check, not proof.
- **Validate:** `ceres`; runtime: `import open_clip` from service Python, both workflows.

#### `comfyui-service-overlay-selection`

- **Review (2026-11-06):** `required`. Selected/live comfyui-nix `58f91b00` [still sets the module packageSet to its own packages](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L348-L357). Full Ceres `ExecStart` selects local `/nix/store/fshaa8qr26pp3xcpsyfdqhbsqax7rqj8-comfy-ui-0.37.0/bin/comfy-ui`, with patched source and `json-repair` `0.55.2`. Default upstream selection still lacks the needed ROCm capability probe, so the coordinated-cutover gate remains unmet.

- **Where:** `modules/nixos/services/comfyui.nix` (`package = pkgs.comfy-ui-rocm`).
- **Why:** upstream module defaults `packageSet` to the flake's own packages ([flake.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L348-L357)), which would bypass the INT8 patch and `json-repair`. Upstream `extraPythonPackages` cannot be combined with a custom package.
- **Remove when:** the default package already contains the INT8 fix; migrate `json-repair` to `services.comfyui.extraPythonPackages` in the same cutover.
- **Validate:** `ceres`; inspect evaluated `ExecStart` package; runtime: enhancer nodes registered, both workflows.

#### `comfyui-rocm-platform-guard`

- **Review (2026-11-06):** `required`. Selected/live comfyui-nix `58f91b00` [still throws outside x86_64 Linux for ROCm](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L332-L339), and its ROCm wheels remain `manylinux_2_28_x86_64`. Full Ceres uses that ROCm selection, while full Juno1 config has `services.comfyui.enable = false`. No new supported ROCm architecture/wheel evidence meets the removal gate.

- **Where:** `overlays/comfyui/default.nix` (`isLinux && isx86_64` branch, `prev.comfy-ui-rocm` fallback).
- **Why:** upstream ROCm package exists only on x86_64 Linux ([flake.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L332-L337)); keeps aarch64 (Juno) evaluation lazy.
- **Remove when:** upstream supports ROCm on another architecture and that platform's wheels are proven; do not enable Ceres's ROCm service on aarch64 because generic ComfyUI supports it.
- **Validate:** `ceres` + `juno1`.

#### `comfyui-qwen-memory-policy`

- **Review (2026-11-06):** `required`. Full Ceres still selects ComfyUI `0.37.0`/torch `2.10.0+rocm7.1`; evaluated service arguments retain `--reserve-vram 5`, and both seeded workflows put the regular text encoder on `cpu`. The exact [Qwen model revision `ace0edeb`](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/tree/ace0edeb3791a594ddfa36ed5f41a178a394e921) remains fetchable (model API revision lookup succeeded). This hardware-fit policy is not invalidated by a new ComfyUI release: no cold/warm 1024×1024 baseline/enhanced workflow memory evidence without the reserve/CPU placement was produced. Keep the recorded policy.

- **Where:** `systems/x86_64-linux/ceres/qwen-image.nix` (VRAM reserve), `systems/x86_64-linux/ceres/qwen-image/int8.json`, `int8-enhanced.json` (CPU text encoder placement).
- **Why:** 5 GiB VRAM reserve for casts/attention scratch on the 16 GiB RX 6950 XT and CPU placement of the Qwen3VL encoder, needed with INT8 storage + full-precision fallback.
- **Upstream:** [Qwen-Image-2.1 ace0edeb](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/tree/ace0edeb3791a594ddfa36ed5f41a178a394e921) and the ComfyUI revisions above. Hardware fit, not an upstream bug.
- **Remove when:** the selected model/kernel/memory management fits both workflows cold and warm (including enhancer load transitions) without the reserve or CPU placement. Update seeded and saved workflows consistently.
- **Validate:** `ceres`; runtime: 1024×1024 baseline and enhanced workflows with memory observation.

### Desktop and graphics

#### `desktop-hyprland-mesa-abi`

- **Review (2026-11-06):** `candidate`. Ceres and Pallas now evaluate the same exact 64-bit Mesa store path from the configured Hyprland package universe and root pkgs (`j6846pd6a2i4bx16wcdn571sq7jznr71-mesa-26.2.6`), and the same exact 32-bit path (`hhxdd360v6ygsaa8wr9536hpvir2585d-mesa-26.2.6`). Root and Hyprland glibc are also the identical `pqyiidz5mi73wv5f91d48s9plcqyj5bz-glibc-2.44-57`. Thus this override currently selects identical packages despite different nixpkgs revisions (1d060086 / 0bb2eedc); candidate, not a guarantee that future independent pins remain coherent. [Hyprland issue #5148](https://github.com/hyprwm/Hyprland/issues/5148) remains closed. Removing the override still needs both desktop builds and accelerated session, capture and 32-bit game runtime checks. The old wiki URL and its current unversioned variant both returned HTTP 404; package identity is independently established by evaluation.

- **Where:** `modules/nixos/desktop/wayland.nix` (`hardware.graphics.package`/`package32` from `inputs.hyprland.inputs.nixpkgs`); enabled by `modules/nixos/hardware/gpu.nix`. README "Desktop graphics" explains the failure.
- **Why:** root Mesa can require a newer glibc than the pinned compositor loads, causing `Cannot open backend: no allocator available` (5299bbf2). Evaluated 2026-10-10: selected Mesa 26.1.5 with Hyprland's glibc 2.42 vs root Mesa 26.2.4 / glibc 2.44.
- **Upstream:** [Hyprland on NixOS (0.54)](https://wiki.hypr.land/0.54.0/Nix/Hyprland-on-NixOS/) still recommends Mesa from Hyprland's nixpkgs. [hyprwm/Hyprland#5148](https://github.com/hyprwm/Hyprland/issues/5148) is closed (2024-03-17), not proof for the current pins.
- **Remove when:** compositor, portal and 64/32-bit Mesa share a coherent package universe (e.g. Hyprland follows root nixpkgs, or its nixpkgs equals root) and the session runs without the override.
- **Validate:** `desktop`; runtime: running Hyprland and `/run/opengl-driver` paths, no loader/GLIBC errors in journal, accelerated rendering, screen sharing; on Ceres a 32-bit Steam/Proton game.

#### `portal-qt-theme-isolation`

- **Review (2026-11-06):** `candidate`. The full Ceres configuration selects xdg-desktop-portal-hyprland `1.5.0+date=2026-11-01_8545044`, source [85450448](https://github.com/hyprwm/xdg-desktop-portal-hyprland/tree/85450448ea40a54ec4f10bd607e68019d8f5cc41), identical to live master. Its [picker CMake](https://github.com/hyprwm/xdg-desktop-portal-hyprland/blob/85450448ea40a54ec4f10bd607e68019d8f5cc41/hyprland-share-picker/CMakeLists.txt) links hyprtoolkit >=0.6.0, not Qt6; selected Nix buildInputs contain hyprtoolkit and no Qt, and the exact source archive has no Qt6/QApplication/QWidget/theme-variable consumer in CMake, Nix or C++ sources. The Qt6 rationale is obsolete. Candidate for removing both UnsetEnvironment names, subject to desktop builds and capture with inherited variables; no runtime proof was produced. [Issue #145](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/145) remains closed and is not removal proof.

- **Where:** `modules/nixos/desktop/wayland.nix` (`xdg-desktop-portal-hyprland` unsets `QT_QPA_PLATFORMTHEME`, `QT_STYLE_OVERRIDE`).
- **Why:** [INFERENCE] isolates the Qt6 share picker from global Qt theme plugins/styles; no failure or upstream fix recorded.
- **Upstream:** pinned portal 08d99f72 uses Qt6 widgets; master e87ae782. [xdg-desktop-portal-hyprland#145](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/145) closed but about ignored themes, not this isolation.
- **Remove when:** the selected portal starts and captures with the variables inherited, with intended theming.
- **Validate:** `desktop`; runtime: browser screen-share picker, capture window/monitor, portal journal clean.

#### `legacy-wlroots-session-flags`

- **Review (2026-11-06):** `unverified`. Full Ceres evaluation still exports both flags. Neither name occurs in `src/` of selected [Hyprland acc1aa0b](https://github.com/hyprwm/Hyprland/tree/acc1aa0bfd4bd575dcb0f76c35ccf12b660a1ab9/src). Live Hyprland main is ab6141897d57e609e24c571a762c30c963e0885a. There is still no established original failure or complete inventory of other session consumers, so retain unverified; the AMD/NVIDIA cursor/render/hotplug/capture gate is not met. The [wlroots source](https://gitlab.freedesktop.org/wlroots/wlroots) remains the consumer-family reference rather than proof of current consumption.

- **Where:** `modules/nixos/desktop/wayland.nix` (`WLR_RENDERER_ALLOW_SOFTWARE`, `WLR_NO_HARDWARE_CURSORS`).
- **Why:** legacy wlroots software-render/cursor flags; neither name occurs in pinned Hyprland `src/`. Possibly stale, but other consumers are not ruled out.
- **Upstream:** [selected Hyprland source](https://github.com/hyprwm/Hyprland/tree/5c9377c15f85c50648f35ca5a213754f95b93ca0/src) has no consumer found for either flag; [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots) remains a possible consumer family. No original failure or fixed revision is identified.
- **Remove when:** actual session consumers are inventoried and cursors/rendering work without each flag on AMD and NVIDIA.
- **Validate:** `desktop`; runtime: login, cursor movement and capture, monitor hotplug, wlroots-based apps.

#### `satty-floating-hack`

- **Review (2026-11-06):** `required`. Selected Satty remains 0.22.0 ([tag commit 9f99065e](https://github.com/Satty-org/Satty/blob/9f99065e4177820e965f5475503e5c3bdbd74e6a/cli/src/command_line.rs#L36-L39)), also latest release; live main [7e7ef403](https://github.com/Satty-org/Satty/blob/7e7ef403599f06ad9a5220f0a76baf997ad0fb62/cli/src/command_line.rs#L54-L57) still declares the compositor-dependent floating hack. The local screenshot launcher and matching window rule remain. Neither region nor monitor flow without the flag was exercised; keep required.

- **Where:** `modules/home/desktop/hyprland/screenshot.nix` (`--floating-hack` plus window rule for `com.gabm.satty`).
- **Why:** Satty's own compositor-dependent floating workaround ([command_line.rs](https://github.com/Satty-org/Satty/blob/f578432a68f3930cc5fd52f2f7d99d54aff0d9ae/cli/src/command_line.rs#L36-L39), still on main); selected Satty 0.22.0.
- **Remove when:** the window rule alone floats Satty for both region and monitor flows.
- **Validate:** `desktop`; runtime: SUPER+S and SUPER+SHIFT+S, annotate, save, copy.

#### `quickshell-store-theme-restart`

- **Review (2026-11-06):** `unverified`. Full Ceres configuration still selects Quickshell 0.3.2 (tag resolves to [4f508be5](https://github.com/quickshell-mirror/quickshell/blob/4f508be500dea6e5732cc3d50382a0048b17e7b1/src/io/fileview.cpp#L494-L547)); 0.3.2 remains the latest release. Selected FileView uses QFileSystemWatcher on the target and parent directory and rearms dropped file watches; live [master 9b0f339b](https://github.com/quickshell-mirror/quickshell/blob/9b0f339b19057f4731bf3b48293307d7ef241671/src/io/fileview.cpp) retains that logic. [Qt documentation](https://doc.qt.io/qt-6/qfilesystemwatcher.html#details) still says renamed/removed files stop being watched, but does not prove this exact atomic-symlink case. No live/packaged symlink-replacement test was run, so classify the unreproduced rationale as unverified and retain the restart trigger; the removal gate is not met.

- **Where:** `modules/home/desktop/quickshell.nix` (`X-Restart-Triggers`), `modules/home/desktop/quickshell/config/Theme.qml`.
- **Why:** the file watcher does not notice the store theme symlink target changing during a switch ([QFileSystemWatcher](https://doc.qt.io/qt-6/qfilesystemwatcher.html) stops watching renamed files; exact case not reproduced).
- **Remove when:** the selected watcher picks up an atomic symlink replacement in live and packaged modes.
- **Validate:** `desktop`; runtime: change theme in a disposable branch, switch, verify colors/fonts/wallpaper update without losing app windows.

#### `quickshell-hyprland-workspace-address`

- **Review (2026-11-06):** `required`. Root nixpkgs 1d060086 still selects Quickshell 0.3.2 ([4f508be5 workspace.cpp](https://github.com/quickshell-mirror/quickshell/blob/4f508be500dea6e5732cc3d50382a0048b17e7b1/src/wayland/hyprland/ipc/workspace.cpp)), with `activate()` dispatching bName and focusedmon/openwindow looking up by name. Live [master 9b0f339b](https://github.com/quickshell-mirror/quickshell/blob/9b0f339b19057f4731bf3b48293307d7ef241671/src/wayland/hyprland/ipc/connection.cpp) still has all three defects; latest release remains 0.3.2. Selected Hyprland 0.57.1 ([acc1aa0b FocusState.cpp](https://github.com/hyprwm/Hyprland/blob/acc1aa0bfd4bd575dcb0f76c35ccf12b660a1ab9/src/desktop/state/FocusState.cpp#L283-L287)) still emits addressableName in focusedmon. Keep the patch; the source gate has not been met. No new runtime run supersedes the November 1 evidence.

- **Where:** `packages/quickshell/default.nix` (`overrideAttrs` under the multimedia wrapper), `packages/quickshell/hyprland-workspace-address.patch`.
- **Why:** Hyprland 0.57 separates a workspace's address from its display name: workspace 8 has address `8` and name `firefox`. Quickshell's `HyprlandWorkspace.activate()` dispatches the name, which Hyprland resolves to a new workspace with address `firefox`. `focusedmon` and `openwindow` carry the address, but Quickshell looks it up among names, so a named workspace loses its focus state after a monitor change and a new window on it has a null workspace. The patch dispatches the same selector as Hyprland's `Workspace::selector()` and looks both events up by address. QML can't repair the built-in `HyprlandToplevel.workspace`, so the fix is in the package. It rebuilds Quickshell instead of using the binary cache.
- **Not changed:** `movewindowv2`, `createworkspacev2` and `j/clients` still match on the name; moved windows and startup pass with distinct names, and duplicate names are untested. Selected 0.3.2 ignores `changeworkspaceid`, so `activate()` uses the old address after an id change until Quickshell restarts; master handles that event.
- **Upstream:** [quickshell-mirror/quickshell#1119](https://github.com/quickshell-mirror/quickshell/issues/1119) (closed 2026-09-21) added address tracking. No issue or PR for these three defects (searched 2026-11-01). Master 9b0f339b has the same `activate()`, `focusedmon` and `openwindow` code.
- **Selected pin:** root nixpkgs 1c89083e, Quickshell v0.3.2 (latest release), Hyprland v0.57.0. Hyprland posts `addressableName()` in `focusedmon` (`src/desktop/state/FocusState.cpp`) and `openwindow` (`src/desktop/view/window/Window.cpp`).
- **Remove when:** the selected Quickshell's `activate()` dispatches an address-based selector and both events resolve by address. Remove the patch and `overrideAttrs`; keep the multimedia wrapper. A patch that no longer applies fails the build and means this review is due.
- **Validate:** `desktop`; `nix build --no-link --no-update-lock-file .#quickshell`. Runtime: activating a renamed workspace selects its numeric address and creates no workspace; after a monitor focus round trip the renamed workspace stays focused; a new window on it reports that workspace.
- **Exercised (2026-11-01):** against live Hyprland 0.57.0, production `rail/Workspaces.qml` under unpatched Quickshell failed all three checks (selected address `firefox`, highlight false, workspace null); moved-window, scratchpad, unnamed-click and rail checks passed. All seven pass on the patched package with no workspace left behind. Full Ceres and Pallas system builds passed. Activated Ceres and verified its installed service runs the patched executable; rails, ignored-output behavior and launcher open/close on both configured monitors passed. Returned to Noctalia after testing; Pallas was not activated.

#### `hex-model-service-selection`

- **Review (2026-11-06):** `required`. Selected Hex is 3.3.0 from [98e4c37f](https://github.com/anomalyco/hex/blob/98e4c37fac07f52c95566e1bebacb2ea24a50255/nix/hm-module.nix#L31), whose install wrapper still runs bare `model install` and whose hexSettings activation remains after reloadSystemd. Live dev [aa79bc25](https://github.com/anomalyco/hex/blob/aa79bc25eb952a5cae0257e7a0bcd5eef5faf717/nix/hm-module.nix#L31) has the same ordering and command. Full Ceres evaluation still produces the explicit `hex model install whisper_large_v3_turbo --language en` override. Keep required; no selected upstream fix or new first-activation runtime proof.

- **Where:** `modules/home/desktop/hex.nix` (`systemd.user.services.hex-model.Service.ExecStart` forced to `hex model install <model> --language <language>` from `programs.hex.model` and `programs.hex.language`).
- **Why:** upstream's `hex-install-model` runs a bare `hex model install`, which reads the model from settings. The `hex-model` service starts during `reloadSystemd`, but `home.activation.hexSettings` applies `programs.hex.model` only after it, so a first install with no settings file downloads Hex's default Parakeet Unified English (731 MB) instead of the declared model. The override names the model and language, so ordering no longer matters. It drops upstream's two-minute wait for `network-online.target`; `Restart=on-failure` with `RestartSec=60` stays, so a login without network retries.
- **Upstream:** no issue or PR (searched 2026-10-31; `docs/nix.md` promises the "selected model"). `dev` b16587bc still runs the bare command in `nix/hm-module.nix` (line 31).
- **Selected pin:** hex 154b4d40, the same bare command in `nix/hm-module.nix` with `hexSettings` at `entryAfter [ "reloadSystemd" ]`; `src/control/cli.rs` `install_model` takes the optional model and `--language`.
- **Remove when:** the selected module's generated `hex-model` command requests the declared model on an empty support directory, or applies settings before the service starts. Remove the `ExecStart` override and the `inherit` entries only it uses.
- **Validate:** `desktop`; evaluate `home-manager.users.sgiath.systemd.user.services.hex-model.Service.ExecStart` through `nixosConfigurations.ceres`, then run it with an empty `HEX_APPLICATION_SUPPORT_DIR` and a blocked `HTTPS_PROXY`: it must print `Installing Whisper large-v3-turbo` and exit non-zero. Runtime: on a first activation `hex-model` installs that model and `hex model status` reports it installed.
- **Exercised (2026-10-31):** with an empty support directory and a proxy on `127.0.0.1:9`, upstream's generated `hex-install-model` printed `Installing Parakeet Unified English (731 MB)`; the evaluated Ceres command printed `Installing Whisper large-v3-turbo` and failed at the proxy with a non-zero exit, which is what `Restart=on-failure` retries. No model was downloaded and the unit was not activated.

#### `preview-share-picker-hyprland-057-ipc`

- **Review (2026-11-06):** `required`. Root nixpkgs is now 1d060086; full Ceres evaluation still selects the unoverridden picker at 0.2.1. [Compare 49c91869...1d060086](https://github.com/NixOS/nixpkgs/compare/49c91869b2ec0738fec7333eba11364ef17509ad...1d060086d60cb76a40cf37109f979d88a5bd6396) reports `behind` (root does not contain the fix). [PR #582643](https://github.com/NixOS/nixpkgs/pull/582643) remains merged as 49c91869, while selected Hyprland is 0.57.1 acc1aa0b. Keep the 0.3.1 override; the selected-source gate is unmet. No new ScreenCast runtime claim.

- **Where:** `modules/home/desktop/share-picker.nix` (`overrideAttrs` on `hyprland-preview-share-picker`: `version`, `src` tag hash, `cargoDeps`).
- **Why:** nixpkgs 0.2.1 lists windows and monitors through `hyprland-rs` 0.4.0-beta.2, whose workspace type requires `id`. Hyprland 0.57 workspace objects in `clients`/`monitors` JSON carry `address`, `name` and `type` instead, so `Clients::get` and `Monitors::get` fail with ``missing field `id` `` and the picker shows only the Region tab. v0.3.1 removed `hyprland-rs` ([PR #29](https://github.com/WhySoBad/hyprland-preview-share-picker/pull/29)): windows come from the portal's `XDPH_WINDOW_SHARING_LIST`, monitors from `wl_output`. It also makes the default region command output-relative ([PR #26](https://github.com/WhySoBad/hyprland-preview-share-picker/pull/26)), which retired `preview-share-picker-region-coordinates`; `region.command` stays only for its absolute `slurp` path, because the portal's `PATH` has no `slurp`.
- **Upstream:** v0.3.1 (07602efe, released 2026-10-17); nixpkgs [#582643](https://github.com/NixOS/nixpkgs/pull/582643) (0.2.1 -> 0.3.1) merged to master 2026-11-04 as 49c91869. The override reuses that PR's `src` and `cargoHash` values.
- **Selected pin:** root nixpkgs 0bb2eedc (committed lock) selects 0.2.1 and is behind 49c91869; Hyprland v0.57.1 in the flake, 0.57.0 live when the failure was captured.
- **Remove when:** root nixpkgs selects `hyprland-preview-share-picker` 0.3.1 or later. Remove the `overrideAttrs` and its comment; keep the dark wrapper and `region.command`.
- **Validate:** `desktop`. Runtime: a ScreenCast request through the portal shows the Outputs and Windows tabs with thumbnails; selecting a monitor, a window and cancelling each return the expected result to the portal.

### Gaming (Ceres)

#### `gaming-gtk2-broken-allowance`

- **Review (2026-11-06):** `required`. Root nixpkgs 1d060086 selects gtk+ 2.24.33 and Lutris 0.5.22. [Selected Lutris recipe](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/pkgs/by-name/lu/lutris/package.nix) has now dropped gtk2 from multiPkgs (only gtk3 remains), as has live master. However Ceres still declares zulu8 for Prism/Nomifactory, and [selected zulu common.nix](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/pkgs/development/compilers/zulu/common.nix#L52-L63) retains gtk2 in runtimeDependencies for Linux JDK<17 with default gtkSupport. [GTK2 removal #410814](https://github.com/NixOS/nixpkgs/issues/410814) remains open; selected and live GTK2 recipe retain problems.broken. Keep the handler until the remaining zulu8 dependency is removed; the old claim that selected Lutris itself pulls GTK2 is now stale.

- **Where:** `modules/nixos/gaming/role.nix` (`nixpkgs.config.problems.handlers."gtk+".broken = "warn"`), so only hosts with the gaming role get it.
- **Why:** selected nixpkgs marks GTK2 `problems.broken` as a removal notice, not a build failure (`pkgs/by-name/gt/gtk2/package.nix` lines 178-184: final release 2.24.33, migrate before NixOS 27.05). Lutris's FHS env lists `gtk2` and `gtk3` in `multiPkgs` (`pkgs/by-name/lu/lutris/package.nix` lines 256-257) for games that load legacy GTK, and Prism Launcher's `zulu8` (Nomifactory) adds `gtk2` because `gtkSupport` defaults on for JDK < 17 (`pkgs/development/compilers/zulu/common.nix` lines 26, 60-61). Without the handler, Ceres evaluation stops on `gtk+-2.24.33` in `lutris-0.5.22-fhsenv-rootfs`. The handler matches only package `gtk+` and problem `broken`; every other broken package still fails, and each evaluation prints the GTK2 warning. Not an `allowBroken` or insecure-package exemption. Vesta's headless Nomifactory server avoids GTK2 with `zulu8.override { gtkSupport = false; }` instead (`modules/nixos/server/minecraft.nix`).
- **Upstream:** [NixOS/nixpkgs#410814](https://github.com/NixOS/nixpkgs/issues/410814) (GTK2 removal tracking) open on 2026-11-03.
- **Selected pin:** root nixpkgs 0bb2eedc; Lutris 0.5.22, `gtk+` 2.24.33.
- **Remove when:** neither the selected Lutris FHS env nor Prism's `zulu8` pulls `gtk+` (Lutris drops `gtk2` from `multiPkgs`, and `zulu8` is dropped, built without GTK, or no longer needed). If nixpkgs removes `gtk2` first, this handler stops helping and Ceres evaluation fails on the missing attribute; replace the dependency then.
- **Validate:** `all` (toplevel drvPath evaluation for every host proves the scope; Ceres must evaluate with only the GTK2 warning); `ceres` build. Runtime: start Lutris and a Nomifactory instance in Prism with `zulu8`.

### Terminal, agents and services

#### `tmux-sessionizer-session-target`

- **Review (2026-11-06):** `candidate`. `modules/home/terminal/tmux.nix` no longer exists, no Nix source references tmux-sessionizer, and full configurations evaluate programs.tmux.enable=false on Ceres, Pallas, Vesta and Juno1. The root package remains tmux-sessionizer 0.6.1; [v0.6.1](https://github.com/jrmoulton/tmux-sessionizer/blob/v0.6.1/src/tmux.rs#L170-L191) and live [main 335eee11](https://github.com/jrmoulton/tmux-sessionizer/blob/335eee11832f1a23caa52c7f76f34ec972f93beb/src/tmux.rs#L170-L191) still pass an unqualified session to new-window, so this is absence of local callers rather than an upstream fix. Keep as candidate pending reconciliation and the registry validation/runtime requirements; do not claim the upstream source gate passed or invent removal proof.

- **Where:** `modules/home/terminal/tmux.nix` (`postPatch` on `tmux-sessionizer`).
- **Why:** `Tmux::new_window` targets an unqualified session name, which tmux can resolve to a matching worktree window. The patch appends `:`.
- **Upstream:** [v0.6.1 tmux.rs](https://github.com/jrmoulton/tmux-sessionizer/blob/v0.6.1/src/tmux.rs) and main 15cc6462 still unqualified; latest release v0.6.1 = selected version.
- **Remove when:** the selected release qualifies the target and the collision scenario passes without the patch. Keep the popup bindings.
- **Validate:** `all`; runtime: run TMS from the popup in a session containing a window whose name starts with the target session name.
- **Exercised (2026-10-01):** isolated tmux 3.7c probe: `-t target` failed "index 0 in use", `-t target:` created the window in the right session.

#### `hermes-agent-home-mode`

- **Review (2026-11-06):** `unknown`. Root input resolution now selects Hermes [2bd378ed](https://github.com/NousResearch/hermes-agent/tree/2bd378ed1b8d6bf2192cb26e0a55ff3091e6bd19), rather than the bf0203a7 source in the historical record. The required security delegate failed to start with model_unavailable for openai-codex/gpt-daybreak-blue-latest; the selected activation/tmpfiles/discovery equivalence was not revalidated. Retain both local mode corrections. No home permissions, gateway state or authenticated cron operation was read or changed.

- **Where:** `modules/nixos/services/hermes-agent.nix` (activation script `hermes-agent-home-mode` after `hermes-agent-setup`, tmpfiles `z` rule; both set `/home/sgiath/hermes/.hermes` to 0700).
- **Why:** the upstream NixOS module makes HERMES_HOME 2770 owned by `sgiath:hermes`, in `hermes-agent-setup` on every activation and in its tmpfiles `d` rule on boot and switch. Hermes' own gateway discovery (`home_mode_unsafe` in `hermes_cli/gateway_runtime_discovery.py`) only accepts a group-writable home when the group is the owner's private group, so `connect_gateway()` fails with `unsafe_control_permissions` and cron jobs that need the gateway (the Oct 24 and 25 screenshot runs) die with `GatewayUnavailableError`. Both services run as `sgiath` and nothing else needs group access to the home, so 0700 is enough. `stateDir`, `workspace` and the state subdirectories stay 2770; discovery doesn't check them.
- **Upstream:** no issue or PR filed for this workaround. Main still sets the tmpfiles rule and the activation `chmod 2770` ([nixosModules.nix](https://github.com/NousResearch/hermes-agent/blob/main/nix/nixosModules.nix), checked 2026-10-25).
- **Selected pin:** hermes-agent bf0203a7, [nixosModules.nix#L446](https://github.com/NousResearch/hermes-agent/blob/bf0203a794a07aac3ff764972ab9087baa4e4f4e/nix/nixosModules.nix#L446) (tmpfiles `d ... 2770`) and [#L466](https://github.com/NousResearch/hermes-agent/blob/bf0203a794a07aac3ff764972ab9087baa4e4f4e/nix/nixosModules.nix#L466) (`chmod 2770`); [gateway_runtime_discovery.py#L50](https://github.com/NousResearch/hermes-agent/blob/bf0203a794a07aac3ff764972ab9087baa4e4f4e/hermes_cli/gateway_runtime_discovery.py#L50) rejects the result.
- **Remove when:** the selected module leaves HERMES_HOME in a mode discovery accepts (or discovery accepts the module's mode) in both activation and tmpfiles. Remove the activation script and the `z` rule together.
- **Validate:** `vesta`; after switch and after boot `stat -c %a /home/sgiath/hermes/.hermes` is `700` and `connect_gateway()` reaches the gateway. Runtime: authenticate with `connect_gateway()` and query `cron.recover` for a nonexistent job/request; expect `status: missing` without submitting a job or sending a message.
- **Exercised (2026-10-25):** on the pinned module the activation mode commands and the tmpfiles rule both left the fixture home 2770, which the deployed discovery policy rejected with `unsafe_control_permissions`. The full Vesta NixOS build passed and was deployed as `/nix/store/yrdnwi92nz026jc7g7dg8a9j1mx1plnm-nixos-system-vesta-26.11.20261023.3ec6363`. Its ordered activation and two tmpfiles fixture runs passed the real discovery policy. On Vesta, `.hermes` stayed 0700 after switch and another tmpfiles run, the same gateway PID remained active, and an authenticated `cron.recover` probe returned `status: missing` without submitting work. All six job schedules matched their pre-switch fingerprint. Scheduled digest execution itself was not replayed.

#### `pihole-first-run-setup-retry`

- **Review (2026-11-06):** `required`. Full Vesta selects FTL 6.8. The [setup script at root nixpkgs 1d060086](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/nixos/modules/services/networking/pihole-ftl-setup-script.nix) is byte-identical to [live master 3c7fa76e](https://github.com/NixOS/nixpkgs/blob/3c7fa76e7261ee7241a26d2a99151aa95d4cd3e5/nixos/modules/services/networking/pihole-ftl-setup-script.nix): it signals SIGRTMIN, retries TestAPIAvailability, then submits lists without waiting for database readiness or retrying addList. The source gate remains unmet. No fresh-state or production-state run was made.

- **Where:** `modules/nixos/services/pi-hole.nix` (`pihole-ftl-setup` `Restart=on-failure`, `RestartSec=5`).
- **Why:** on fresh state the upstream setup script creates `gravity.db`, signals FTL and posts lists immediately; the first request can fail "Database not available".
- **Upstream:** pinned [pihole-ftl-setup-script.nix](https://github.com/NixOS/nixpkgs/blob/e7439b6b14ad3cc35d05608ebca9bce01a25f5f8/nixos/modules/services/networking/pihole-ftl-setup-script.nix#L76-L95) still only probes API availability, not database reopen. No upstream issue/fix known.
- **Remove when:** the selected setup script waits for database readiness (or retries list submission) and a disposable fresh-state run provisions all lists without the retry. Never reset production Pi-hole state to test.
- **Validate:** `vesta`; runtime: disposable fresh-state setup succeeds, lists exist, DNS resolves; populated-state rerun stays idempotent.

#### `searx-json-secret-interpolation`

- **Review (2026-11-06):** `unknown`. Root nixpkgs now resolves to [1d060086](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/nixos/modules/services/networking/searx.nix). The required credential-handling review failed to start: model_unavailable for openai-codex/gpt-daybreak-blue-latest. Safe selected-module serialization and restart equivalence were not revalidated. Retain jq --rawfile and the existing runtime credential wiring; no credential values or production settings were read.

- **Where:** `modules/nixos/services/searx.nix` (`searx-init` replaced with `jq --rawfile`).
- **Why:** upstream `envsubst` interpolates secrets unescaped into JSON strings; jq encodes them correctly while keeping runtime credentials and restart wiring.
- **Upstream:** pinned [searx.nix](https://github.com/NixOS/nixpkgs/blob/e7439b6b14ad3cc35d05608ebca9bce01a25f5f8/nixos/modules/services/networking/searx.nix#L31-L37) still uses `envsubst`. No upstream issue recorded.
- **Remove when:** the selected module serializes credential strings safely at runtime; reconcile favicon/limiter generation first; keep restart wiring. Credential handling review belongs to the security model.
- **Validate:** `vesta`; runtime: fixture with special characters round-trips, `searx-init` and SearXNG start, a search works.

#### `executor-state-ownership-migration`

- **Review (2026-11-06):** `unknown`. Full Vesta still selects ghcr.io/rhyssullivan/executor-selfhost:1.6.10; [the historical upstream Dockerfile](https://github.com/UsefulSoftwareCo/executor/blob/3890d6f5e5efd1530f0dba0fe23ada95a39caf86/apps/host-selfhost/Dockerfile#L28) remains the prior UID evidence. The security delegate failed to start with model_unavailable for openai-codex/gpt-daybreak-blue-latest. Image-user and retained-volume/backup/rollback ownership were not revalidated. Keep both tmpfiles rules; no volume contents, ownership or production state was changed.

Also covers audit ID `executor-root-to-nonroot-state-migration`.

- **Where:** `modules/nixos/services/executor.nix` (tmpfiles `d` + recursive `Z` for uid/gid 65532 on `/data/executor`).
- **Why:** images up to 1.6.8 ran as root; selected 1.6.10 is distroless nonroot (`USER 65532`, [Dockerfile](https://github.com/UsefulSoftwareCo/executor/blob/3890d6f5e5efd1530f0dba0fe23ada95a39caf86/apps/host-selfhost/Dockerfile#L28)). `Z` migrates existing root-owned state; `d` stays as the ongoing rule.
- **Remove `Z` when:** every retained volume, restored backup and supported rollback target is already 65532-owned; keep the `d` rule aligned with the image UID.
- **Validate:** `vesta`; runtime: read-only owner check (`stat`/`find -not -user 65532`, no content reads), container start/restart, health and persistence.

#### `executor-registry-image-version-selection`

- **Review (2026-11-06):** `required`. Full Vesta evaluation still selects `ghcr.io/rhyssullivan/executor-selfhost:1.6.10`; read-only `scripts/update-executor.sh --dry-run` reports already at 1.6.10. Latest GitHub release is now [v1.6.11](https://github.com/UsefulSoftwareCo/executor/releases/tag/v1.6.11). Its [self-host image publishing workflow](https://github.com/UsefulSoftwareCo/executor/blob/v1.6.11/.github/workflows/publish-selfhost-docker.yml#L4-L10) is workflow_dispatch with an explicit tag, not guaranteed publishing on every release. Thus matching-image guarantee remains absent, and the release/registry mismatch directly supports retaining registry-based version selection. No updater mutation or deployment occurred.

- **Where:** `scripts/update-executor.sh` (highest semver tag on `ghcr.io/rhyssullivan/executor-selfhost`).
- **Why:** not every GitHub release publishes an image (comment: 1.6.9 had none), so the updater follows registry tags, not releases. Concrete version pinning in the module (never `:latest`) is a separate deliberate rule.
- **Upstream:** [v1.6.10](https://github.com/UsefulSoftwareCo/executor/releases/tag/v1.6.10) is latest; registry also at 1.6.10.
- **Exercised (2026-10-01):** `scripts/update-executor.sh --dry-run` → "already at 1.6.10".
- **Remove when:** upstream guarantees a matching image for every release, or the updater design changes deliberately. Matching versions today are not enough.
- **Validate:** `vesta`; runtime: deployed image tag and Executor health after switch.

#### `ollama-rocm-gfx-override-dormant`

- **Review (2026-11-06):** `dormant`. Full NixOS evaluation confirms services.ollama.enable=false on all four hosts; Ceres root nixpkgs 1d060086 exposes ollama-rocm 0.40.13. The local gfx10.3.0 override remains. Live [Ollama GPU documentation](https://docs.ollama.com/gpu) still documents HSA_OVERRIDE_GFX_VERSION and gfx1030/10.3.0 compatibility; no GPU inference probe was run. Keep dormant and re-establish the actual selected runtime's GPU support before enablement.

- **Where:** `modules/nixos/services/ollama.nix` (`ollama-rocm`, gfx 10.3.0 override); referenced from `systems/x86_64-linux/ceres/default.nix`.
- **Why:** spoofs the ROCm GPU target. Evaluated 2026-10-01: Ollama disabled on every host.
- **Upstream / selected pin:** [Ollama GPU support](https://docs.ollama.com/gpu) is the compatibility reference; no original issue or fixed revision is recorded. Root nixpkgs currently exposes `ollama-rocm` 0.40.0 (evaluated 2026-10-10; Ollama still disabled on every host), but this dormant service has no exercised GPU runtime.
- **Remove/change when:** before enabling, establish GPU support for the selected ROCm/Ollama and run real inference without spoofing.
- **Validate:** `ceres` on enablement; runtime: GPU detected, inference works.

### Local packages and scripts

#### `katrain-kivy-python-api`

- **Review (2026-11-06):** `required`. Full Ceres selects KaTrain 1.20.0, Python 3.13.16 and package-local Kivy 2.3.1. [KaTrain v1.20.0/f4981cf9](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml) still requires Python >=3.11,<3.14; it remains the latest release. Root nixpkgs 1d060086 still supplies Kivy 2.3.1-unstable-2026-07-11 from [d8e642fe](https://github.com/kivy/kivy/tree/d8e642fec15894ce338b0c9773c3f58b41b75f09), while default Python is 3.14.8. Kivy's latest release remains 2.3.1 and [#9225](https://github.com/kivy/kivy/issues/9225) is still open. Neither the compatible-dependency nor UI/audio gate is met.

- **Where:** `packages/katrain/default.nix` (Python 3.13 + package-local Kivy 2.3.1 with pyproject relaxations and mtdev path patch); consumer `homes/x86_64-linux/sgiath@ceres/default.nix`.
- **Why:** KaTrain 1.20.0 needs Python `>=3.11,<3.14` and Kivy 2.3.1 APIs; root nixpkgs has Kivy `2.3.1-unstable-2026-07-11`.
- **Upstream:** KaTrain latest v1.20.0 ([pyproject](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml)); Kivy latest 2.3.1; [kivy#9225](https://github.com/kivy/kivy/issues/9225) open (the local comment claiming Python 3.14 support merged is unreliable).
- **Remove when:** a selected nixpkgs dependency set satisfies KaTrain's actual Python/Kivy requirements and runs its UI/audio. Keep normal mtdev/build-dependency packaging if still needed.
- **Validate:** `ceres`; runtime: open KaTrain, load a game, UI and audio work.

#### `davinci-resolve-mcp-sdk-version`

- **Review (2026-11-06):** `required`. Full Ceres now selects Resolve MCP 4.19.2 and a package-local SDK 1.30.0; root nixpkgs 1d060086 instead supplies SDK 2.3.0. Selected/latest [v4.19.2/cab652f0 requirements](https://github.com/samuelgursky/davinci-resolve-mcp/blob/cab652f0e6dc2347b4ed4ea9425d9f7573b9a87d/requirements.txt) still require mcp>=1.30,<2, and the already-built selected server imports mcp.server.fastmcp at src/server.py:263. The implementation now builds SDK 1 independently rather than overriding the SDK 2 recipe. Keep that isolation until Resolve accepts the selected root SDK; the earlier 4.10.4/SDK-1.29 rationale is historical. No new native Resolve or authenticated runtime check was made.

- **Where:** `packages/davinci-resolve-mcp/default.nix` (package-local SDK 1 recipe).
- **Why:** Resolve MCP 4.10.4 requires `mcp>=1.30,<2`, but the selected nixpkgs package is 1.29.0. SDK 2 removes the `mcp.server.fastmcp` interface used by the server.
- **Upstream / selected pin:** [Resolve MCP requirements](https://github.com/samuelgursky/davinci-resolve-mcp/blob/v4.10.4/requirements.txt); [SDK 1.30.0](https://github.com/modelcontextprotocol/python-sdk/releases/tag/v1.30.0). The local override selects that tagged SDK without changing other MCP clients' package sets.
- **Remove when:** selected nixpkgs provides an SDK accepted by Resolve MCP with `mcp.server.fastmcp`; remove the package-local SDK recipe and use `python3.pkgs.mcp`.
- **Validate:** `ceres` and `nix build --no-link .#davinci-resolve-mcp`; import Resolve's native scripting module inside its FHS environment, reject unauthenticated HTTP requests, initialize an authenticated MCP session, list tools, and query the running Resolve version through Executor.
- **Exercised:** 2026-10-10: SDK checks (1212 passed), full Ceres and Vesta builds, Juno1 system evaluation, native scripting import, HTTP authentication and Host rejection, authenticated discovery of 37 tools, quiet journald logging, and a live Resolve Studio 21.1.0.17 version query through Executor passed.

#### `t3code-nightly-sea-patchelf`

- **Review (2026-11-06):** `required`. Full Ceres selects nightly 0.1.8-nightly.20261106.4275 and root patchelf 0.19.2 with no patches. [Fix #672](https://github.com/NixOS/patchelf/pull/672) merged as 3e996dbe; [compare fix...0.19.2](https://github.com/NixOS/patchelf/compare/3e996dbef1fa0658012f8dd290bddcf0302acade...0.19.2) is behind by 2. Latest [0.19.3](https://github.com/NixOS/patchelf/releases/tag/0.19.3) contains it (ahead 21, behind 0), but neither the selected recipe nor live nixpkgs master 3c7fa76e selects that release. [#146](https://github.com/NixOS/patchelf/issues/146) is now closed; [#446](https://github.com/NixOS/patchelf/issues/446) and [#674](https://github.com/NixOS/patchelf/issues/674) remain open. Keep the local 0.15.5 pin; the new nightly was not repatched with the unoverridden tool or executed by this audit.

- **Where:** `packages/t3code-nightly/default.nix` (`patchelfForSea`, put first on `PATH` for the explicit `autoPatchelf` in `postFixup`).
- **Why:** patchelf 0.18+ moves `.interp`, `.gnu.hash`, `.dynsym`, `.dynstr` and `.dynamic` of the T3 Node SEA into a new RW `PT_LOAD` at `0x3ff000`, but the next read-only `PT_LOAD` (`0x4003b0`-`0x811f38`) still overlaps it. The kernel maps the later segment over the earlier one, so `.dynamic` ends up `r--p` and ld.so dies with `SIGSEGV`/`SEGV_ACCERR` in `dl_main` when it writes `DT_DEBUG`. The build then fails on `t3 --completions` with exit 139. patchelf 0.15 keeps `.dynamic` in its own RW page, so the package runs autoPatchelf with patchelf 0.15.5.
- **Upstream:** no issue for this exact layout; it is the same failure class as [NixOS/patchelf#146](https://github.com/NixOS/patchelf/issues/146) and [#446](https://github.com/NixOS/patchelf/issues/446) (`PT_DYNAMIC` ends up in a non-writable segment), both open. patchelf master has no commits after 0.19.2 (checked 2026-10-20).
- **Selected pin:** root nixpkgs 09063bd1 has patchelf 0.19.2 as `patchelf` and 0.18.0-unstable-2025-08-13 as `patchelfUnstable`; both produce the crash. The previous lock used patchelf 0.15.2.
- **Remove when:** nixpkgs `patchelf` patches the selected SEA (`--set-interpreter` then `--set-rpath`, like auto-patchelf) into a binary where `t3 --version` runs. Remove `patchelfForSea` and the `PATH` prefix.
- **Validate:** `nix build --no-link .#t3code-nightly` (completions and install check run the SEA); `readelf -lW libexec/t3code/t3` shows `DYNAMIC` inside a RW `LOAD` that no other `LOAD` overlaps.
- **Exercised (2026-10-20):** on 0.1.1-nightly.20261020.3386 with the same stdenv, the package failed with exit 139 on patchelf 0.19.2 and built with patchelf 0.15.5. The same nightly built with the previous lock. Patching the pristine SEA by hand with only the patchelf version changed: 0.15.2 and 0.15.5 run, 0.18.0-unstable and 0.19.2 segfault. The fixed build runs `--version`, `--help`, writes all three completions, and every bundled native helper resolves its libraries.

#### `katrain-kivy-cython-long`

- **Review (2026-11-06):** `required`. Full Ceres still selects package-local Kivy 2.3.1 ([20d74dcd](https://github.com/kivy/kivy/tree/20d74dcd30f143abbd1aa94c76bafc5bd934d5bd)) and Cython 3.3.0 from root 1d060086. The fetched source still contains long(self.__ref__()) in weakproxy.pyx:257 and the unconverted dict_keys assignment in instructions.pyx:899. [Python-2 removal #8610](https://github.com/kivy/kivy/pull/8610) is merged, but comparing dcd8fb2a to the selected release is diverged, and direct selected-file inspection confirms the fixes are absent. Latest Kivy remains 2.3.1. No replacement or source gate is met; historical build evidence was not rerun.

- **Where:** `packages/katrain/default.nix` (Kivy `postPatch` replacing Python 2 `long` in `weakproxy.pyx`, `context_instructions.pyx`, `opengl.pyx`, and the PY2 `dict_keys` assignment in `instructions.pyx`).
- **Why:** Kivy 2.3.1 does not build with current Cython. Cython 3.2 dropped the `long` builtin. Cython 3.3 also type-checks the dead `if PY2:` branch of `RenderContext.apply` and fails with `instructions.pyx:899:41: Cannot assign type 'dict_keys object' to 'list object'`, so that branch now uses the same `list(self.state_stacks.keys())` as the Python 3 one.
- **Upstream:** fixed on Kivy HEAD 9bd35c59 ([weakproxy.pyx](https://github.com/kivy/kivy/blob/9bd35c595760fe6909e6889b9aefe659a57f9eae/kivy/weakproxy.pyx#L250)); the `instructions.pyx` branch went away in [kivy#8610](https://github.com/kivy/kivy/pull/8610) (dcd8fb2a), which removed all Python 2 compatibility code. Neither is in release 2.3.1, which is selected.
- **Selected pin:** root nixpkgs Cython 3.3.0 for the package-local Python 3.13 set.
- **Remove when:** the selected Kivy contains these fixes and satisfies KaTrain; remove the replacements before `--replace-fail` breaks.
- **Validate:** `ceres` and `nix build --no-link .#katrain`; runtime: KaTrain renders and analyzes a board.
- **Exercised (2026-10-20):** without the `instructions.pyx` replacement the full Ceres build failed in Kivy with the Cython 3.3 error above. With it Kivy and KaTrain build (35 KaTrain tests pass, the GPU test stays deselected), the full Ceres build passes, and headless imports of `kivy.graphics.instructions`, `kivy.core.audio` and `katrain.core.game` work. The UI wasn't started.

#### `katrain-chardet-major-version`

- **Review (2026-11-06):** `required`. Full Ceres's actual KaTrain dependencies still include chardet 6.0.0.post1. Selected/latest [KaTrain f4981cf9 pyproject.toml:23](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml#L23) still requires >=5.2.0,<6, so the version-relaxation gate remains unmet. No non-UTF-8 game-file import was exercised.

- **Where:** `packages/katrain/default.nix` (`pythonRelaxDeps` for `chardet`).
- **Why:** KaTrain requires `chardet>=5.2.0,<6` ([pyproject L23](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml#L23)); root nixpkgs ships 6.0.0.post1.
- **Remove when:** the selected KaTrain accepts the selected chardet (or a compatible chardet is used).
- **Validate:** `ceres`; runtime: import non-UTF-8 SGF/NGF/GIB files, names/comments decode.

#### `katrain-bundled-katago-appimage`

- **Review (2026-11-06):** `required`. Selected/latest [KaTrain v1.20.0/f4981cf9](https://github.com/sanderland/katrain/tree/f4981cf905cece90085ce4e3967415d0c16d525f/katrain/KataGo) still contains an ELF with the AppImage type-2 AI header. The already-built full-Ceres selection's extracted KataGo has DT_NEEDED libzip.so.4; selected libzip 1.11.4 provides libzip.so.5 instead. This confirms that extraction and the retained ABI library are still relevant. No OpenCL analysis/move runtime proof was produced.

- **Where:** `packages/katrain/default.nix` (extract bundled OpenCL KataGo AppImage, keep its `libzip.so.4`, drop Windows assets).
- **Why:** avoids FUSE/AppRun assumptions in the sandbox; nixpkgs libzip has another soname. Keeps upstream's engine rather than silently switching to nixpkgs KataGo.
- **Upstream:** [KaTrain KataGo dir](https://github.com/sanderland/katrain/tree/f4981cf905cece90085ce4e3967415d0c16d525f/katrain/KataGo); rationale is local, not re-reproduced.
- **Remove when:** the selected release ships a NixOS-compatible engine with OpenCL and ABI deps, or extraction becomes unnecessary.
- **Validate:** `ceres`; runtime: OpenCL engine analysis and a move on Ceres (`--help` is not proof).

#### `katrain-opencl-test-exclusion`

- **Review (2026-11-06):** `required`. Selected/latest [KaTrain f4981cf9 tests/test_ai.py](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/tests/test_ai.py#L17-L20) still skips test_ai_strategies in CI because there is no OpenCL, and constructs KataGoEngine in the test. Full Ceres's package still excludes only that test. There is no selected hermetic/CPU-backed replacement; no check-phase or GPU runtime run was made.

Also covers audit ID `package-katrain-opencl-test`.

- **Where:** `packages/katrain/default.nix` (disables only `test_ai_strategies`; temporary `HOME`).
- **Why:** the test constructs `KataGoEngine` and needs an OpenCL device; upstream itself skips it in CI ([test_ai.py](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/tests/test_ai.py#L17)).
- **Remove when:** the test becomes hermetic/CPU-backed, or the sandbox gets a deterministic software OpenCL.
- **Validate:** `ceres` plus package check phase; runtime as `katrain-bundled-katago-appimage`.

#### `whiteboard-angle-runpath`

- **Review (2026-11-06):** `required`. Full Ceres now selects Whiteboard 0.5.1, also [latest release, source 8c348e98](https://github.com/devdotfast/whiteboard/releases/tag/v0.5.1). The exact selected DEB's original libGLESv2.so has no RPATH/RUNPATH and contains libEGL.so.1/libGL.so.1 loader names. The already-built selected package's same library has libglvnd 1.7.0 on RUNPATH after the local appendRunpaths. The native library-resolution gate remains unmet; no canvas runtime check was made.

- **Where:** `packages/whiteboard/default.nix` (runtime dlopen deps; libglvnd appended to all relevant RUNPATHs).
- **Why:** bundled ANGLE loads libEGL/libGL itself; `runtimeDependencies` only reaches executables.
- **Upstream:** selected/latest [v0.2.4](https://github.com/devdotfast/whiteboard/releases/tag/v0.2.4) (2026-10-10).
- **Remove when:** a selected package/native build resolves EGL/GL without the extra RUNPATH.
- **Validate:** `desktop`; runtime: `whiteboard-desktop` and CLI-launched desktop render a canvas on Wayland.

#### `whiteboard-cli-desktop-environment`

- **Review (2026-11-06):** `required`. Full Ceres selects Whiteboard 0.5.1 from [8c348e98](https://github.com/devdotfast/whiteboard/blob/8c348e988bf5f91c45a9ad8b0a2748680ac0985f/packages/review/src/review-app-launcher.ts#L312-L346), also latest. Its launcher now clears ELECTRON_RUN_AS_NODE, VSCODE_DEV and VSCODE_CLI itself, but in Electron still launches process.execPath, bypassing the Nix desktop wrapper. Its fallback Linux launcher is /usr/bin/review-desktop. The selected CLI still needs the shared runtime PATH for git/xdg-utils; the complete wrapper contract is not supplied upstream. Keep the record, with only the environment-clearing part now duplicated; cold/warm/direct launch and external-link checks were not run.

- **Where:** `packages/whiteboard/default.nix` (both wrappers add git/xdg-utils; desktop clears `ELECTRON_RUN_AS_NODE`/`VSCODE_*`; CLI sets `ELECTRON_RUN_AS_NODE`; desktop file `Exec` rewritten).
- **Why:** the CLI launches the desktop through `process.execPath`, bypassing the desktop wrapper.
- **Upstream:** selected/latest [Whiteboard v0.2.4](https://github.com/devdotfast/whiteboard/releases/tag/v0.2.4) (2026-10-10). No equivalent native-NixOS launcher contract or specific upstream fix was established.
- **Remove when:** the selected CLI routes launches through a supported wrapper keeping the environment on cold/warm launch.
- **Validate:** `desktop`; runtime: CLI-initiated and direct desktop launches from an environment containing the Electron/VSCode variables; git and external links work.

#### `openclaw-desktop-deep-link-wrapper`

- **Review (2026-11-06):** `required`. Full Ceres selects OpenClaw Desktop 2026.11.1, also [latest stable, commit 4ffdd204](https://github.com/openclaw/openclaw/blob/4ffdd2047d192dd65554de3c8c46c0e0197c6e2a/apps/linux/src-tauri/src/main.rs#L3487-L3498). The selected source still invokes deep_link().register_all() on Linux and has no Nix wrapper path integration there. Keep the packaged desktop-handler path; no isolated cold-open URI test was made and the user's handler was untouched.

- **Where:** `packages/openclaw-desktop/default.nix` (no `update-desktop-database` on PATH; shipped `OpenClaw.desktop` handles `openclaw://`).
- **Why:** runtime registration would point the handler at the unwrapped ELF.
- **Upstream:** selected/latest stable [v2026.9.9](https://github.com/openclaw/openclaw/releases/tag/v2026.9.9) (2026-10-10).
- **Remove when:** the selected Tauri/plugin integration registers the wrapped launcher on NixOS, verified on cold launch.
- **Validate:** `desktop`; runtime: in an isolated desktop profile cold-open an `openclaw://` URI. Never overwrite the user's handler to test.

#### `openclaw-desktop-remote-ssh-limitation`

- **Review (2026-11-06):** `required`. Full Ceres selects the 2026.11.1 DEB. [Its tag source 4ffdd204](https://github.com/openclaw/openclaw/blob/4ffdd2047d192dd65554de3c8c46c0e0197c6e2a/apps/linux/src-tauri/src/remote_gateway.rs#L1030-L1040) and freshly fetched main both still construct /usr/bin/ssh and /bin/ssh candidates rather than consulting PATH. The source gate is unmet; no SSH session was opened. The existing FIXME's one-path wording remains stale.

- **Where:** `packages/openclaw-desktop/default.nix` (FIXME; binary not patched).
- **Why:** remote gateway only tries `/usr/bin/ssh` and `/bin/ssh` (the FIXME mentions only the first); neither exists on NixOS, so remote-gateway mode does not work.
- **Upstream:** selected [v2026.9.9 remote_gateway.rs](https://github.com/openclaw/openclaw/blob/v2026.9.9/apps/linux/src-tauri/src/remote_gateway.rs#L1046) and [main 7f9594b2](https://github.com/openclaw/openclaw/blob/7f9594b2338497adf41a3c92cc9c6aa49b85eb02/apps/linux/src-tauri/src/remote_gateway.rs#L1028) still hardcode both paths (2026-10-10).
- **Resolve when:** the downloaded `.deb` actually includes a PATH/configurable ssh fix; then drop the FIXME.
- **Validate:** `desktop`; runtime: authorized SSH connection to a test gateway.

#### `openclaw-desktop-asset-aware-updater`

- **Review (2026-11-06):** `required`. Full Ceres selects [latest stable v2026.11.1](https://github.com/openclaw/openclaw/releases/tag/v2026.11.1), whose release API includes OpenClaw-2026.11.1-amd64.deb. The current release list still has a stable [v2026.9.36](https://github.com/openclaw/openclaw/releases/tag/v2026.9.36) without a Linux DEB, alongside newer releases that do have one. The durable all-releases asset contract is therefore still absent. No updater mutation or gateway runtime run was made.

- **Where:** `packages/openclaw-desktop/update.sh` (highest stable release that has `OpenClaw-<version>-amd64.deb`).
- **Why:** stable releases do not reliably ship a Linux `.deb`: on 2026-10-10 the latest stable 2026.9.9 has one, while 2026.9.8, 2026.8.35, 2026.8.34 and 2026.9.7 do not (the 2026.10.1 betas have none either).
- **Upstream:** selected [v2026.9.9](https://github.com/openclaw/openclaw/releases/tag/v2026.9.9) has the required Linux asset; the preceding [v2026.9.8](https://github.com/openclaw/openclaw/releases/tag/v2026.9.8) does not. A newer project version alone is not a removal gate.
- **Remove when:** upstream has a durable Linux release-asset contract, or the package source type changes deliberately.
- **Validate:** `desktop`; runtime: OpenClaw local gateway and control UI after an update.

#### `nak-network-check-disable`

- **Review (2026-11-06):** `required`. Full Ceres exposes nak 0.22.2, also latest, from [07562de2](https://github.com/fiatjaf/nak/blob/07562de29368755358a2776b43cc26056af66d33/cli_test.go#L165-L180). Its TestReqIdFromRelay and TestReqWithFlagsAfter1 still query public nos.lol. The package retains doCheck=false; no sandbox/offline-only test selection was established, so the broad exclusion stays. No network tests or relay calls were run.

Also covers audit ID `package-nak-network-tests`.

- **Where:** `packages/nak/default.nix` (`doCheck = false`); package exposed, not installed (`modules/home/terminal/role.nix` entry commented).
- **Why:** some tests contact public Nostr relays (selected [v0.21.2 cli_test.go](https://github.com/fiatjaf/nak/blob/v0.21.2/cli_test.go#L166-L180) runs `nak req … nos.lol`); others are offline, so the blanket skip is broader than needed. Selected = latest v0.21.2 (2026-10-10).
- **Remove when:** upstream makes relay tests opt-in/hermetic, or packaging selects only offline tests that pass in the sandbox.
- **Validate:** package build with checks and network disabled (meaningful tests run) plus `ceres`/`vesta`/`juno1` boundary; runtime: `nak` help and offline encode/decode.

#### `cross-architecture-nixos-rebuild-no-reexec`

- **Review (2026-11-06):** `candidate`. The selected full-Ceres nixos-rebuild-ng 26.11 [reexec implementation at root 1d060086](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/services.py#L29-L80) already catches failed os.execve, explicitly including another CPU architecture, and re-execs the current local binary. [Live master 3c7fa76e](https://github.com/NixOS/nixpkgs/blob/3c7fa76e7261ee7241a26d2a99151aa95d4cd3e5/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/services.py#L29-L80) retains that fallback. This addresses the recorded incompatible-executable failure at source level. It still builds the target's rebuild derivation before the fallback; no end-to-end x86-to-aarch64 build/deploy proof was produced. Keep the flag pending ceres/juno1 validation and an authorized deployment. The separate --store-path use is outside this candidate; selected __init__.py:365-378 already bypasses reexec when args.store_path is set, so its old lookup rationale does not establish a current need for the flag.

- **Where:** `packages/update/default.nix` (`--no-reexec` for `update --juno<N>`).
- **Why:** with `--build-host`/`--target-host` on aarch64, re-exec would replace the local x86_64 `nixos-rebuild` with the target's aarch64 binary.
- **Upstream:** [nixos-rebuild-ng](https://github.com/NixOS/nixpkgs/tree/b4fd65b198c599cbe814fcb9f42d25d021595ec9/pkgs/by-name/ni/nixos-rebuild-ng); no upstream change identified.
- **Remove when:** the selected rebuild keeps a runnable local binary for x86→aarch64 deployment.
- **Validate:** `ceres`, `juno1`; runtime: an authorized `update --juno1`.

#### `burn-iso-hybrid-mbr-key-partition`

- **Review (2026-11-06):** `unknown`. The selected ISO resolves to nixos-minimal-26.11.20261103.1d06008-x86_64-linux.iso, but its output /nix/store/jx6nw8h3hi8lrinn0ccmcj7rmq6k5kpg-nixos-minimal-26.11.20261103.1d06008-x86_64-linux.iso is absent. The geometry check therefore could not run under the audit's no-build boundary. [Selected iso-image.nix at root 1d060086](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/nixos/modules/installer/cd-dvd/iso-image.nix#L1023-L1029) still supports hybrid MBR/EFI construction, but that is not partition-geometry proof. Retain the adaptation; no image was built, device written, key exported or runtime boot performed.

- **Where:** `packages/burn-iso/default.nix` (settle/unmount, append `SGIATH-KEYS` via `sfdisk` to the hybrid ISO's MBR).
- **Why:** hybrid GPT/MBR geometry overlaps and the kernel reads the MBR; gptfdisk is unsuitable. No upstream issue; local layout evidence only.
- **Upstream:** no external fix/issue is identified: this is a local hybrid-ISO layout adaptation, not a package bug. Recheck the generated image geometry when its pinned inputs change.
- **Remove/change when:** the generated ISO geometry supports another strategy, proven on disposable media.
- **Validate:** `iso`; runtime: loop device/VM or expendable USB with fake keys boots and exposes the key partition.

### Kernels

#### `dgx-spark-nvidia-kernel-cve-2026-98432`

- **Review (2026-11-06):** `unknown`. Input resolution still selects dgx-spark c646a19a and full Juno1 evaluation reports kernel 7.0.14-nvidia. The required security review failed to start with model_unavailable for openai-codex/gpt-daybreak-blue-latest, so live NV-Kernels and inclusion of [Linux fix e3f33b0a](https://github.com/torvalds/linux/commit/e3f33b0a1d89d738e2b913dab519226eaf76e15b) in the fetched source were not revalidated. Retain the backport. The historical static-only/deployment warning remains; this audit provides no kernel build, reboot or vulnerability-remediation proof.

- **Where:** `modules/nixos/hardware/dgx-spark.nix` (`boot.kernelPatches`), `modules/nixos/hardware/cve-2026-98432-ipv4-opt-rcu.patch` (the upstream commit, unmodified).
- **Why:** CVE-2026-98432 is a use-after-free. `inet_sock_destruct()` and `tcp_v4_reqsk_destructor()` free IPv4 options with plain `kfree()` while the SYNACK paths read them under `rcu_read_lock()` only. The patch changes both to `kfree_rcu(..., rcu)`. It goes through `boot.kernelPatches` because the kernel is built inside the upstream module; NixOS appends the patch in the `.override` of `boot.kernelPackages`.
- **Upstream:** [torvalds/linux e3f33b0a](https://github.com/torvalds/linux/commit/e3f33b0a1d89d738e2b913dab519226eaf76e15b), committed 2026-10-05. NV-Kernels `24.04_linux-nvidia-7.0-next` (58b5de53) and `24.04_linux-nvidia-bos-7.0-next` (e01bfd69) still use plain `kfree()` in both destructors, and [graham33/nixos-dgx-spark](https://github.com/graham33/nixos-dgx-spark) main is still the selected c646a19a (checked 2026-10-30).
- **Selected pin:** `dgx-spark` c646a19a selects NV-Kernels ae07646a (`7.0.14-nvidia`, tag `Ubuntu-nvidia-7.0-7.0.0-1019.19_24.04.2`), with plain `kfree()` at [af_inet.c#L165](https://github.com/NVIDIA/NV-Kernels/blob/ae07646a606b3f18707246b0762464452cb40cbe/net/ipv4/af_inet.c#L165) and [tcp_ipv4.c#L1232](https://github.com/NVIDIA/NV-Kernels/blob/ae07646a606b3f18707246b0762464452cb40cbe/net/ipv4/tcp_ipv4.c#L1232).
- **Remove when:** the NV-Kernels source selected by `inputs.dgx-spark` has `kfree_rcu(..., rcu)` in both destructors. The patch then stops applying and fails the kernel build, which is the prompt to check. Remove the `boot.kernelPatches` entry and the patch file together.
- **Validate:** `juno1`, including the native build. `nix derivation show` on `.#nixosConfigurations.juno1.config.boot.kernelPackages.kernel.drvPath` lists the patch in `patches`, and patching runs without fuzz. Runtime: after `update --juno1` and a reboot, `/run/booted-system/kernel` and `/run/current-system/kernel` resolve to the same rebuilt kernel, and the host boots with Nebula, RoCE and the GPU working. A switch without a reboot leaves the old kernel running.
- **Exercised (2026-10-30):** static only. The patches of the evaluated `linux-7.0.14-nvidia` derivation were applied with `--fuzz=0` to the pinned `af_inet.c` and `tcp_ipv4.c`: the unpatched derivation (s5jj8l7a) failed the destructor check and the patched one (rp8zlrpx) passed. The Juno1 toplevel evaluates, its derivation closure selects the patched kernel, the NVIDIA module derivation depends on it, and the upstream module's `overrideAttrs` reference scrubbing is unchanged. The kernel was not built or booted and the bug was not reproduced; Juno1 must be treated as vulnerable until this is deployed and rebooted.

### Security exceptions

Records from the security lifecycle audit. Bundled runtimes are invisible to nixpkgs `knownVulnerabilities`, so these deadlines are checked here. No `permittedInsecurePackages`, `allowInsecure`, `knownVulnerabilities` or `NIXPKGS_ALLOW_INSECURE` exists in the repository (2026-10-10).

#### `whiteboard-bundled-electron`

- **Review (2026-11-06):** `unknown`. Full Ceres now selects [Whiteboard 0.5.1/8c348e98](https://github.com/devdotfast/whiteboard/releases/tag/v0.5.1), replacing the historically checked 0.2.4. The required security delegate failed to start with model_unavailable for openai-codex/gpt-daybreak-blue-latest. Neither its bundled runtime major nor the corresponding [Electron support deadline](https://releases.electronjs.org/schedule.json) was revalidated. The previous 43/2027-01-05 watch date is 60 days away and is historical, not a verified deadline for 0.5.1. Retain the exception; no current expired or within-30-day deadline can be ruled out from this failed review.

Also covers audit ID `package-whiteboard-bundled-electron`.

- **Where:** `packages/whiteboard/default.nix` (binary DEB with bundled Electron; current runtime major unverified).
- **Historical status (2026-10-10):** `watch` — Electron 43 EOL **2027-01-05** ([schedule](https://releases.electronjs.org/schedule.json)). Selected = latest upstream [v0.2.4](https://github.com/devdotfast/whiteboard/releases/tag/v0.2.4) (5b00f0e6) pins 43.7.9 ([electron checksums](https://github.com/devdotfast/whiteboard/blob/v0.2.4/apps/review-desktop/code-oss/build/checksums/electron.txt)); the packaged `share/whiteboard/whiteboard` of the selected `whiteboard-0.2.4` reports `Electron/43.7.9` (checked 2026-10-10). The earlier Electron 42 deadline (2026-10-20) no longer applies. On each manual review, warn before the date; after it, set `expired` and report.
- **Remove when:** the package no longer bundles its own Electron. Until then, move the deadline to the packaged major's EOL on each update (verify both source metadata and packaged runtime).
- **Validate:** `desktop`; runtime: desktop launch, CLI-to-desktop launch, one review/canvas flow.

## Deliberate choices (not upstream workarounds)

Not part of the manual upstream review. Revisit only when the named trigger
happens; do not remove them because upstream changed. Group names are stable.

| Group | Audit IDs | Where | Why it is not a workaround / revisit trigger |
| --- | --- | --- | --- |
| `channel-selection` | `master-channel-node26-selection`, `master-channel-factorio-experimental-selection`, `tuios-no-upstream-overlay-adapter` | `overlays/sgiath/default.nix` | Freshness preference (both currently equal root versions) and package-only input adapter. Revisit on freshness-policy change. |
| `executor-nebula-integrations` | `executor-private-network-access` | `modules/nixos/services/executor.nix`, `modules/home/agents/davinci-resolve-mcp.nix` | The personal self-hosted Executor may call authenticated MCP services on Nebula. `EXECUTOR_ALLOW_LOCAL_NETWORK=true` permits private endpoints; Resolve MCP binds only its Nebula address and requires a runtime bearer token. Revisit if Executor gains a narrower per-integration address allowlist. |
| `release-pins` | `ordinary-root-release-pins`, `standard-input-follows-and-overlays`, `flake-binary-cache-configuration`, `comfyui-upstream-release-pin` | `flake.nix`, `scripts/update-inputs.sh` | Ordinary tagged/immutable input refs advanced by the release updater, per-input `nixpkgs` follows, module wiring, upstream overlays, and substituter/key preferences. Only `hyprland-glaze-release-freeze` is a pin workaround; Hyprland's nixpkgs not following root is tracked in `desktop-hyprland-mesa-abi`. Trust/cache changes are separate scope. |
| `bird-product` | `bird-native-linux-chromium-cookie-source`, `bird-standard-pnpm-recipe`, `hermes-bird-vesta-command-adapter` | `vendor/bird/src/lib/cookies.ts`, `vendor/bird/src/lib/chromium-cookies.ts`, `packages/bird/default.nix`, `modules/nixos/services/hermes-bird-vesta.sh` | Required read-only open-Chromium cookie reading (v11 keyring unsupported), normal pnpm recipe, digest command adapter. Credential/security changes need the security model. |
| `comfyui-product` | `comfyui-cache-registration`, `comfyui-json-repair`, `comfyui-prompt-enhancer-node`, `comfyui-rocm-attention-policy`, `comfyui-bundled-nodes-opt-out`, `comfyui-qwen-service-state`, `comfyui-qwen-workflow-seeding`, `comfyui-qwen-model-downloads` | `flake.nix` nixConfig, `overlays/comfyui/default.nix`, `modules/nixos/services/comfyui.nix`, `systems/x86_64-linux/ceres/qwen-image.nix`, `systems/x86_64-linux/ceres/qwen-image/` | Cache opt-in, enhancer dependency/node pin, ROCm attention policy, node surface, user-owned state, edit-preserving workflow seeding, verified model downloader. `json-repair` migrates with `comfyui-service-overlay-selection`. |
| `package-recipes` | `local-product-packaging`, `katrain-package-integration-details`, `openclaw-tauri-binary-layout`, `whiteboard-legacy-alias-removal`, `delta-authenticated-archive-packaging`, `relay-tester-manual-git-hash-refresh`, `quickshell-qtmultimedia-extension`, `quickshell-multimedia-and-qml-tooling` | `packages/`, `modules/home/desktop/quickshell.nix` | Ordinary reproducible packaging, binary relocation, QtMultimedia for video wallpaper. |
| `updater-and-maintenance` | `dnd5etools-split-image-release-policy`, `local-maintenance-and-installer-commands`, `development-shell-and-input-updater-policy`, `nebula-certificate-mobile-helpers` | `packages/dnd5etools/`, `packages/update/`, `packages/clear-cache/`, `packages/fix-images/`, `packages/live-install/`, `packages/burn-iso/`, `scripts/`, `shells/default/` | Local tools and update policy (dnd5etools images advanced manually by decision). |
| `security-policy` | `whiteboard-user-namespace-sandbox`, `grok-sandbox-off`, `installer-exported-keys-and-mobile-config`, `factorio-default-fetch-flow`, `factorio-headless-runtime-settings`, `matrix-livekit-runtime-turn-settings`, `normal-service-restart-and-auth-integrations` | `packages/whiteboard/default.nix`, `modules/home/agents/base.nix`, `packages/burn-iso/default.nix`, `scripts/nebula-mobile.sh`, `modules/nixos/gaming/role.nix`, `modules/nixos/services/factorio.nix`, `modules/nixos/services/matrix.nix`, agent/service modules | Intentional security-sensitive decisions: inert setuid helper removed (user-namespace sandbox, no `--no-sandbox`), explicit `GROK_SANDBOX=off`, exported installer keys, approved Factorio token handling, runtime credential serialization, service restart/auth boundaries. Change only by owner/security decision; never auto-remove. |
| `session-lifecycle` | `desktop-once-per-session-startup`, `desktop-launcher-independent-app-cgroups`, `herdr-managed-desktop-environment`, `docker-delayed-workstation-start`, `qml-local-reactivity-patterns`, `quickshell-icon-lookup-cost` | `modules/home/desktop/role.nix`, `modules/home/programs/chat.nix`, `modules/home/programs/email.nix`, `modules/home/agents/herdr-server.nix`, `modules/home/desktop/quickshell/`, `modules/nixos/services/docker.nix` | Required once-per-session startup, app cgroup isolation, Herdr daemon ownership and graphical environment, boot policy, local QML patterns, launcher icon omission (owned by the proposed icon-lookup note). |
| `module-wiring` | `stylix-global-overlay-ownership`, `worktrunk-module-precedence`, `noctalia-v5-module-and-visual-contract`, `herdr-theme-parser-integration`, `theme-base16-dark-metadata` | `modules/nixos/desktop/stylix.nix`, `modules/home/desktop/stylix.nix`, `modules/home/terminal/worktrunk.nix`, `modules/home/terminal/herdr.nix`, `modules/home/desktop/noctalia.nix`, `themes/`, `flake.nix` module lists | Chosen module providers (HM worktrunk module disabled in favor of upstream's; HM Noctalia instead of the flake module), overlay ownership, theme data contract. Change only with the provider design. |
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
| `agent-orchestrator-tmux-locale-shim`, `agent-orchestrator-go-patchelf-rpath`, `agent-orchestrator-angle-dlopen`, `agent-orchestrator-bundled-electron` | 5549fac4 | Removed together with `packages/agent-orchestrator` (last selected 0.13.4); no consumer remains at 9426fcce. Upstream v0.13.6 still resolves Electron 33.4.11 (EOL 2025-04-28), so reintroducing the package reopens the expired exception. |
| `clawpatch-trust-lockfile` | 5549fac4 | Removed together with `packages/clawpatch` (last selected 0.8.2); no `trust-lockfile`/`prePnpmInstall` remains at 9426fcce. Upstream v0.8.2 keeps `minimumReleaseAge: 2880`; reintroducing the package must not carry the bypass forward without an owner decision. |
| `relay-tester-check-disable` | 2026-10-10 | Re-enabled the default Rust check phase: pinned a8483f82 (= upstream HEAD) defines no tests. Owner validates the package build with checks after removal. |
| `stylix-release-check-suppression` | 2026-10-10 | Release checks re-enabled: NixOS, Home Manager and Stylix all report 26.11 at 9426fcce, so nothing was suppressed. Owner validates `desktop` builds without release warnings. |
| `home-manager-gpg-ssh-unit-cycle` | 2026-10-10 | Override removed: pinned Home Manager dfadbe51 contains e9cbe698 and no longer orders `set-SSH_AUTH_SOCK` against socket providers (2026-10-01 read-only comparison gave identical fields). Owner validates `all` and a real login without the ordering cycle. |
| `amd-radv-nofibril` | 2026-10-10 | Flag removed: selected Mesa 26.1.5 `radv_perftest_options` has no `nofibril`, so it was a no-op. Owner compares a game/shader-compilation workload on Ceres after removal. |
| `davinci-resolve-21-1-republished-hash` | 2026-10-10 | Overlay removed: root nixpkgs contains NixOS/nixpkgs#562336 (748f45f3) and its corrected hashes; upstream `davinci-resolve-studio` is used. The only consumer stays commented out in `homes/x86_64-linux/sgiath@ceres/default.nix`. Owner validates the package and licensed runtime on enablement. |
| `sops-nix-build-go126-fork` | 2026-10-10 | Input moved to `github:Mic92/sops-nix`, locked at the same 16954c1c (identical narHash; Mic92 master contains it). Owner validates `all` and sops activation after removal. |
| `pihole-ftl-gcc16-unused-counter` | 2026-10-28 | Overlay and patch removed: root nixpkgs selects FTL 6.8, whose `src/config/validator.c` `sanitize_dns_hosts` (lines 1016-1024) already lacks the counter ([pi-hole/FTL#2939](https://github.com/pi-hole/FTL/pull/2939), merged 2026-07-07), so the backport failed to apply (`Reversed (or previously applied) patch detected!`). The unchanged package build reproduced that failure; after removal the upstream cached package and full Vesta toplevel build pass. Runtime checks remain for deployment: `pihole-ftl` healthy, local `dns.hosts` names and public DNS answer. |
| `desktop-hyprland-elf-wrapper` | 2026-10-29 | Override removed: selected Hyprland v0.57.0 (0aa6745f) `nix/default.nix` takes `makeBinaryWrapper` directly (lines 7, 167) and wraps `bin/Hyprland` with `wrapProgram` adding binutils, hyprland-guiutils, pciutils and pkgconf to PATH (lines 255-263), so the stale `makeWrapper` override failed evaluation (`unexpected argument 'makeWrapper'`). After removal `programs.hyprland.package` is the unmodified upstream derivation and the full Ceres toplevel builds; `ensure-wrapper-integrity` accepts the ELF launcher and validates all capabilities. Runtime launch through greetd's `start-hyprland` with screen sharing remains unchecked pending activation. |
| `preview-share-picker-region-coordinates` | 2026-11-05 | Retired with the 0.3.1 pin (`preview-share-picker-hyprland-057-ipc`): v0.3.1 `src/config.rs` defaults `region.command` to `slurp -f '%o@%X,%Y,%W,%H'` (output-relative, PR #26). The setting stays, unchanged, for its absolute `slurp` path. Runtime region selection on a monitor away from the layout origin remains to be checked after activation. |

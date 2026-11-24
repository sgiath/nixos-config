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

Baseline of this manual review: repository `b1a85fff`, checked 2026-11-15.
Resolved through `flake.inputs`: root `nixpkgs` d5cc6833, `home-manager`
a1293da7, `hyprland` 11cbc6c5 (v0.57.2; its nixpkgs f4a03c00), `comfyui`
a78b8b01 (its nixpkgs f4a03c00), `sops-nix` 11e5885d, `snowfall-lib`
6ee3542c, `nixpkgs-master` 19899058, `nixpkgs-ksa` 670a3617, `llm-agents`
aeb1afe1, `hermes-agent` 3b421578 (v0.23.1) and `dgx-spark` c646a19a.
Re-resolve them for each manual review; never read bare lock nodes, which may
name nested dependencies.

The **Review (2026-11-15)** entries give the current status and supersede older
upstream/selected-pin claims in each record; historical **Exercised** evidence
keeps its original date. Every active record was checked, including the seven
security/credential-sensitive ones, reviewed by the security model this time.
Three records remain `unknown`: Bird (no equivalent fetchable upstream
established), Executor state ownership (retained-state ownership on Vesta
deliberately not inspected) and burn-iso (selected ISO output absent, not built).
Several records' Where/Selected pin/Why fields are outdated (named in their
Review entries) and should be corrected in the change that next touches each
workaround. No workaround was removed, input upgraded, package/system built or
host deployed by this audit.

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
| [`nginx-2026-11-security-release`](#nginx-2026-11-security-release) | security backport | required | vesta |
| [`sctp-module-block`](#sctp-module-block) | security mitigation | required | all |
| [`otelcol-contrib-swiss-go127`](#otelcol-contrib-swiss-go127) | temporary fix | required | ceres, pallas, vesta, juno1 |
| [`llm-agents-codex-aws-lc-openssl-shim`](#llm-agents-codex-aws-lc-openssl-shim) | temporary fix | required | all |
| [`hermes-agent-node-patchelf`](#hermes-agent-node-patchelf) | temporary fix | required | vesta |
| [`hermes-agent-home-mode`](#hermes-agent-home-mode) | compatibility | required | vesta |
| [`snowfall-flake-utils-plus-deferred-config`](#snowfall-flake-utils-plus-deferred-config) | vendored fork | required | all |
| [`ksa-unmerged-nixpkgs-package`](#ksa-unmerged-nixpkgs-package) | input fork | required | ceres |
| [`bird-unavailable-upstream-vendoring`](#bird-unavailable-upstream-vendoring) | vendored source | unknown | ceres, vesta |
| [`comfyui-rocm-int8-probe`](#comfyui-rocm-int8-probe) | temporary fix | dormant | ceres, juno1 |
| [`comfyui-python-package-set`](#comfyui-python-package-set) | compatibility | dormant | ceres, juno1 |
| [`comfyui-open-clip-broken-allowance`](#comfyui-open-clip-broken-allowance) | compatibility | dormant | ceres |
| [`comfyui-service-overlay-selection`](#comfyui-service-overlay-selection) | compatibility | dormant | ceres |
| [`comfyui-rocm-platform-guard`](#comfyui-rocm-platform-guard) | compatibility | dormant | ceres, juno1 |
| [`comfyui-qwen-memory-policy`](#comfyui-qwen-memory-policy) | compatibility | dormant | ceres |
| [`desktop-hyprland-mesa-abi`](#desktop-hyprland-mesa-abi) | ABI | required | desktop |
| [`legacy-wlroots-session-flags`](#legacy-wlroots-session-flags) | compatibility | unverified | desktop |
| [`satty-floating-hack`](#satty-floating-hack) | compatibility | required | desktop |
| [`quickshell-store-theme-restart`](#quickshell-store-theme-restart) | compatibility | unverified | desktop |
| [`quickshell-hyprland-workspace-address`](#quickshell-hyprland-workspace-address) | compatibility | required | desktop |
| [`hex-model-service-selection`](#hex-model-service-selection) | temporary fix | required | desktop |
| [`gaming-gtk2-broken-allowance`](#gaming-gtk2-broken-allowance) | compatibility | required | ceres |
| [`pihole-first-run-setup-retry`](#pihole-first-run-setup-retry) | temporary fix | required | vesta |
| [`pihole-module-src-tag`](#pihole-module-src-tag) | temporary fix | required | vesta, hygiea |
| [`searx-json-secret-interpolation`](#searx-json-secret-interpolation) | temporary fix | required | vesta |
| [`executor-state-ownership-migration`](#executor-state-ownership-migration) | data migration | unknown | vesta |
| [`executor-registry-image-version-selection`](#executor-registry-image-version-selection) | updater constraint | required | vesta |
| [`katrain-kivy-python-api`](#katrain-kivy-python-api) | compatibility | required | ceres |
| [`katrain-kivy-cython-long`](#katrain-kivy-cython-long) | temporary fix | required | ceres |
| [`katrain-chardet-major-version`](#katrain-chardet-major-version) | compatibility | required | ceres |
| [`katrain-bundled-katago-appimage`](#katrain-bundled-katago-appimage) | compatibility | required | ceres |
| [`katrain-opencl-test-exclusion`](#katrain-opencl-test-exclusion) | test exception | required | ceres |
| [`whiteboard-angle-runpath`](#whiteboard-angle-runpath) | compatibility | required | desktop |
| [`whiteboard-cli-desktop-environment`](#whiteboard-cli-desktop-environment) | compatibility | required | desktop |
| [`nak-network-check-disable`](#nak-network-check-disable) | test exception | required | package only (not installed) |
| [`davinci-resolve-mcp-sdk-version`](#davinci-resolve-mcp-sdk-version) | compatibility | required | ceres |
| [`t3code-nightly-trusted-networks`](#t3code-nightly-trusted-networks) | security exception | required | ceres, pallas, vesta |
| [`t3code-nightly-arm64-sea-page-size`](#t3code-nightly-arm64-sea-page-size) | compatibility | required | package only (aarch64 refused) |
| [`t3code-antigravity-mcp-config`](#t3code-antigravity-mcp-config) | compatibility | required | ceres, pallas, vesta |
| [`cross-architecture-nixos-rebuild-no-reexec`](#cross-architecture-nixos-rebuild-no-reexec) | compatibility | candidate | ceres, juno1 |
| [`burn-iso-hybrid-mbr-key-partition`](#burn-iso-hybrid-mbr-key-partition) | compatibility | unknown | iso |
| [`dgx-spark-nvidia-kernel-cve-2026-98432`](#dgx-spark-nvidia-kernel-cve-2026-98432) | security backport | required | juno1 |
| [`pallas-alc298-speaker-init`](#pallas-alc298-speaker-init) | missing kernel quirk | required | pallas |
| [`whiteboard-bundled-electron`](#whiteboard-bundled-electron) | security exception | watch | desktop |

### Flake inputs, overlays and vendoring

#### `nginx-2026-11-security-release`

- **Where:** `overlays/sgiath/default.nix` (`nginxStable` is `pkgs-master.nginxStable` while the selected one is older than 1.30.7). `services.nginx.package` defaults to `nginxStable`; only Vesta enables nginx.
- **Why:** nginx2root ([Xint write-up](https://xint.io/blog/nginx2root-remote-code-execution)). CVE-2026-123007 (HTTP/2 flow-control window overflow, unauthenticated RCE) and CVE-2026-123633 (HTTP/2 use-after-free when proxying) both apply to Vesta: 22 vhosts set `http2 on`, most proxy to backends, and `193.165.30.198:443` negotiates `h2`. CVE-2026-121810 (HTTP/3), CVE-2026-123634 (resolver with variable `proxy_pass` and `mirror`) and CVE-2026-113425 (mail proxy) need configurations Vesta does not use. 1.30.7 fixes all five, plus CVE-2026-125283 (`try_files` with `alias`).
- **Upstream:** [nginx security advisories](https://nginx.org/en/security_advisories.html) (not vulnerable: 1.30.7+, 1.31.9+). nixpkgs [f0a5d452](https://github.com/NixOS/nixpkgs/commit/f0a5d452dd) (`nginx: 1.30.6 -> 1.30.7`, master, 2026-11-18).
- **Selected pin:** root nixpkgs `1a08097f` has 1.30.6; `nixpkgs-master` `c48e80bc` has 1.30.7.
- **Remove when:** the selected root nixpkgs has `nginxStable` 1.30.7 or newer. The guard then returns upstream's package; delete the overlay attr.
- **Validate:** `vesta`; `nix eval --raw .#nixosConfigurations.vesta.config.services.nginx.package.version` is 1.30.7 or newer. Runtime: `/proc/<nginx master pid>/exe` is the 1.30.7 store path (a reload does not replace the binary) and the public vhosts still answer over `h2`.
- **Exercised (2026-11-18):** before the change Vesta evaluated and ran 1.30.6; after it the evaluated `ExecStart` is `nginx-1.30.7`.

#### `otelcol-contrib-swiss-go127`

- **Review (2026-11-15):** `required`. The selected generated collector `0.155.0` source still pins [Swiss b0f6560f, which excludes Go 1.27](https://github.com/cockroachdb/swiss/blob/b0f6560f979b/runtime_go1.20.go#L25). Root d5cc6833 defaults to Go `1.27.3`; the local override selects `1.26.11`. Live Swiss now admits Go 1.27, but that revision is not selected, and selected/live nixpkgs still use collector `0.155.0`. The removal assessment is unchanged.

- **Changed (2026-11-18):** the override applies only while the selected `opentelemetry-collector-contrib` is version `0.155.0`; a new release builds with the default Go again, and if its swiss pin still excludes that Go, its build fails with `undefined: hashFn`. Root `1a08097f` still selects 0.155.0 with default Go 1.27 (`buildGoModule = buildGo127Module`), so the Ceres collector derivation is unchanged (`d32bcz01…-otelcol-contrib-0.155.0.drv`).

- **Where:** `overlays/sgiath/default.nix` (while `prev.opentelemetry-collector-contrib.version == "0.155.0"`, `opentelemetry-collector-contrib` is `otelcol-contrib` from `opentelemetry-collector-releases.override { buildGoModule = buildGo126Module; }`; otherwise upstream's attr). Only the compiler of the final Go build changes: the generated source derivation, version, `vendorHash` and the other collector distributions are unchanged. Both the HM `otel-agent` (`modules/home/agents/archive.nix`) and the Vesta collector (`modules/nixos/services/agent-archive.nix`) use this attr.
- **Why:** otelcol-contrib `0.155.0`'s generated `go.mod` requires Go 1.25 and pins `github.com/cockroachdb/swiss v0.0.0-20251224182025-b0f6560f979b`. That revision's `runtime_go1.20.go`, which defines `hashFn`, `getRuntimeHasher` and `fastrand64`, is built only under `(go1.20 && !go1.27) || untested_go_version`. Default `buildGoModule` is Go 1.27, so the build fails with `undefined: hashFn`. Go 1.26 is inside the range swiss tested; the `untested_go_version` tag was rejected because it builds runtime-linked hashing on an unvalidated runtime.
- **Upstream:** [cockroachdb/swiss](https://github.com/cockroachdb/swiss) and [open-telemetry/opentelemetry-collector-contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib); live status was not checked by this change.
- **Selected pin:** root nixpkgs `1a08097f`: `pkgs/tools/misc/opentelemetry-collector/releases.nix` 0.155.0 with default `buildGoModule = buildGo127Module`. (Checked 2026-11-09 on `f4a03c00`: Go 1.27.3 default, `buildGo126Module` Go 1.26.10.)
- **Remove when:** the selected otelcol-contrib is no longer 0.155.0 and builds (the guard has then switched the override off), or nixpkgs builds 0.155.0 with a compatible Go itself. Remove the overlay attr only.
- **Validate:** `ceres`, `vesta` (all hosts carry `otel-agent`); also `nix build --no-link --no-update-lock-file .#nixosConfigurations.vesta.pkgs.opentelemetry-collector-contrib`. Runtime: `otel-agent` and Vesta's `opentelemetry-collector` start and new rows reach the `otel` database.
- **Exercised (2026-11-09):** before the change the collector build failed with the undefined swiss symbols; `go build ./...` of the extracted swiss module under Go 1.27 reproduced them exactly. After the change the attr evaluates to `otelcol-contrib-0.155.0` built with Go 1.26.10, and its source derivation (`yhn9jz02…-otelcol-contrib-src-0.155.0.drv`) is identical to the original. The collector built successfully and reports version 0.155.0; both full Ceres and Vesta toplevels passed, including validation of their generated collector configs. Live service/telemetry checks were not run; no activation was requested.

#### `llm-agents-codex-aws-lc-openssl-shim`

- **Review (2026-11-15):** `required`. Nothing changed in the removal assessment. Selected/live llm-agents [aeb1afe1 still relies on AWS-LC's compat openssl.pc](https://github.com/numtide/llm-agents.nix/blob/aeb1afe1529c5dc7dcdc54d644a8aed212d99dd0/packages/codex/package.nix#L113-L136), while [root d5cc6833 defaults to a prefixed AWS-LC without the shim](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/pkgs/by-name/aw/aws-lc/package.nix#L18-L20). Ceres now selects Codex `0.169.0`; retain the Codex override and its T3 propagation.

- **Changed (2026-11-18):** the three overrides apply only while the `aws-lc` among upstream codex's `buildInputs` lacks `ENABLE_DIST_PKG_OPENSSL_SHIM=TRUE` or has a `BORINGSSL_PREFIX` flag; when llm-agents passes a shimmed, unprefixed AWS-LC, nixpkgs makes that the default, or codex drops AWS-LC, `llm-agents` is upstream's set unchanged. Evaluated against llm-agents `aca6bfb2` and root `1a08097f`: upstream codex (default AWS-LC) and a shim-only AWS-LC both select the override, the overridden codex reads as fixed, and Ceres `llm-agents.codex` (`0ah7ssqx…-codex-0.169.1.drv`) and `llm-agents.t3code` (`7xv3b701…-t3code-0.1.10.drv`) are unchanged.

- **Where:** `overlays/sgiath/default.nix` (`llm-agents`: `codex` is called with `aws-lc.override { withOpenSSLShim = true; symbolPrefix = null; }`; `t3code` is overridden with that `codex`, and `t3code-desktop` with that `t3code`). `modules/home/agents/codex.nix` uses `llm-agents.codex`; `packages/t3code-nightly` and `packages/t3code-nightly-desktop` put `llm-agents.t3code.providerPackages` on `PATH`.
- **Why:** the recipe dropped OpenSSL and builds `openssl-sys 0.9.111` against AWS-LC "through its compat openssl.pc", so only one libcrypto is linked. nixpkgs AWS-LC `5.12.0` (`ENABLE_DIST_PKG`) installs only `aws-lc.pc`, `libcrypto-awslc.pc` and `libssl-awslc.pc` unless `withOpenSSLShim` is set, so `pkg-config openssl` fails ("Could not find directory of OpenSSL installation"). With the shim alone, `openssl-sys`'s `run_bindgen.rs` panics: "aws-lc installation has prefixed symbols, but bindgen-cli does not support removing prefixes", because nixpkgs prefixes symbols with `AWS_LC` by default; `symbolPrefix = null` removes the prefix. llm-agents' own nixpkgs pin predates the nixpkgs AWS-LC change, so its CI does not hit this. Replacing `codex` in the `llm-agents` attrset does not change the `codex` that llm-agents' own scope passes to `t3code`, whose `providerPackages` would otherwise keep the unfixed Codex in both system closures through the nightly T3 wrappers.
- **Upstream:** llm-agents [`packages/codex/package.nix`](https://github.com/numtide/llm-agents.nix/blob/aca6bfb2440503d090003b1064a44df8a8a54b5f/packages/codex/package.nix) at the selected `aca6bfb2` lists `aws-lc` without OpenSSL and relies on the compat `openssl.pc` (lines 98-112). No issue or PR searched.
- **Selected pin:** llm-agents `aca6bfb2` (Codex 0.169.1) through `overlays.shared-nixpkgs`, built against root nixpkgs `1a08097f`, whose AWS-LC 5.12.0 still defaults to `symbolPrefix = "AWS_LC"` and `withOpenSSLShim = false`.
- **Remove when:** the selected llm-agents codex builds against root nixpkgs without it (it lists OpenSSL again, or passes a shimmed AWS-LC itself), or nixpkgs AWS-LC installs an unprefixed `openssl.pc` by default. The guard switches the override off for a shimmed, unprefixed AWS-LC; delete the whole `llm-agents` attr then. If codex lists OpenSSL while keeping the prefixed AWS-LC, the guard still applies the shim, so check that case by hand.
- **Validate:** `all`; also `nix build --no-link --no-update-lock-file .#nixosConfigurations.ceres.pkgs.llm-agents.codex` (install check runs `codex --version`); `ldd` on `libexec/codex/bin/codex` resolves `libcrypto-awslc` and `libssl-awslc` from one AWS-LC store path and no OpenSSL. Neither the nightly T3 CLI nor desktop derivation, nor either system closure, references the unfixed Codex. Runtime: `codex exec` completes a prompt.
- **Exercised (2026-11-10):** before the change the Ceres build (`8ap9irgx…-codex-0.167.0.drv`) failed in `openssl-sys` (`openssl.pc` not found; `PKG_CONFIG_PATH` held only `aws-lc-5.12.0-dev` for crypto). With `withOpenSSLShim = true` alone (`1c8rhy2l…-codex-0.167.0.drv`) it failed with the prefixed-symbols panic. After the change Ceres `llm-agents.codex` is `3r9hn920…-codex-0.167.0.drv`, the only Codex derivation in `llm-agents.t3code` (`zcfiwmsg…`). `codex --version` reports `codex-cli 0.167.0`; `ldd` resolves `libcrypto-awslc.so.1`, `libssl-awslc.so.1`, `libsqlite3`, `libonig` and `libzstd` from the store with no OpenSSL and no missing libraries. A live model prompt was not run.

#### `hermes-agent-node-patchelf`

- **Review (2026-11-15):** `required`. Full Vesta now selects Hermes input `3b421578` (`v0.23.1`), whose [PM recipe still applies patchelf #672 without a version guard](https://github.com/NousResearch/hermes-agent/blob/3b421578588243f920886e6fe79a6faa87ea026e/nix/pm-packages.nix#L53-L69); live main retains it. Root d5cc6833 still selects unpatched patchelf `0.15.2`. Derivation inspection confirms the locally corrected Node `26.12.1` uses that root patchelf. The removal assessment is unchanged; no build or dashboard runtime check was run.

- **Where:** `overlays/sgiath/default.nix` (`hermes-agent`: while the selected `patchelf` is older than 0.18, every `pmPackages` artifact's `patchelf` native input is replaced by the selected, unpatched `patchelf`; from 0.18 on the attr is upstream's package unchanged). The earlier node-only patchelf 0.15.5 pin is gone.
- **Why:** Hermes builds its TUI, web UI and wrapper on the upstream `node-v26.12.1-linux-x64` binary pinned in `pm/lock.json`, fixed up by `autoPatchelfHook` (`--set-interpreter`, then `--set-rpath`). patchelf 0.18+ then leaves `.dynamic` in a RW `PT_LOAD` that the next read-only `PT_LOAD` overlaps, so node exits 139 (details under Exercised). Hermes' [`nix/pm-packages.nix`](https://github.com/NousResearch/hermes-agent/blob/2bd378ed1b8d6bf2192cb26e0a55ff3091e6bd19/nix/pm-packages.nix#L55-L88) answers this by appending patchelf#672 (`59acc3d9`, written against 0.19.2) to whatever `patchelf` nixpkgs selects and putting it first in the native inputs of every Linux PM artifact (node, python, uv, ffmpeg, ripgrep, ...). Root nixpkgs now selects patchelf 0.15.2, where 4 of the patch's 6 hunks fail, so `patchelf-0.15.2` (`hcs1ifln…`) and every PM artifact fail. 0.15.x predates the regression and handled this node layout in the 2026-10-23 bisect, so below 0.18 no patch is needed or applicable; at 0.18+ Hermes' own patched patchelf stays in charge. Same failure class as `t3code-nightly-sea-patchelf`.
- **Upstream:** [NixOS/patchelf#674](https://github.com/NixOS/patchelf/issues/674) (interpreter before RPATH breaks the binary); [#672](https://github.com/NixOS/patchelf/pull/672) merged 2026-10-20 as `3e996dbe`, released in 0.19.3. Hermes [`pm-packages.nix`](https://github.com/NousResearch/hermes-agent/blob/2bd378ed1b8d6bf2192cb26e0a55ff3091e6bd19/nix/pm-packages.nix#L55-L88) applies the patch without checking the patchelf version. No Hermes issue or PR searched; live status not checked by this change.
- **Selected pin:** Hermes input `ae2a81cc` follows root nixpkgs `1a08097f`, whose patchelf is 0.15.2 with no patches; its `nix/pm-packages.nix` still builds `patchelfFixed` (the #672 patch on the selected patchelf, lines 55-69) and puts it before the hook in every Linux PM artifact (lines 101-102), without a version check (checked 2026-11-18).
- **Remove when:** the selected Hermes applies its patchelf patch only to versions that need it (or drops it), or the selected nixpkgs `patchelf` is 0.18+ again. Then remove the whole `hermes-agent` attr and confirm `node --version` from `.#nixosConfigurations.vesta.config.services.hermes-agent.package.hermesNpmLib.nodejs` runs.
- **Validate:** `vesta`; `nix build --no-link .#nixosConfigurations.vesta.config.services.hermes-agent.package` (the TUI build runs npm on the patched node); `node --version` from `hermesNpmLib.nodejs` runs, and `readelf -lW` on its `bin/node` shows `DYNAMIC` inside a RW `LOAD` that no other `LOAD` overlaps. No derivation in the service closure references the #672-patched patchelf. Runtime: `hermes-dashboard` serves the TUI (`HERMES_DASHBOARD_TUI=1`).
- **Exercised (2026-11-09):** before the change the Vesta build failed in `hcs1ifln…-patchelf-0.15.2.drv` (Hermes' patched patchelf) with 4 of 6 hunks rejected. After the change the service package evaluates to `18blj8mx…-hermes-agent-0.0.0.drv`; its PM artifacts in the closure (`bsfx12fz…-node-26.12.1.drv`, `agr6grr7…-ffmpeg-9.0.1.drv`, `w84xr745…-ripgrep-15.2.0.drv`) take the root `patchelf-0.15.2` (`vqds8qd1…`, no patches) plus `auto-patchelf-hook`, and nothing in the closure references `hcs1ifln…` or the #672 patch. `hermesNpmLib.nodejs` is `r7caqnh0…-nodejs-26-npm-12.drv`. The service package (including its TUI/web builds) and full Vesta toplevel built. The adapter runs `node --version` as `v26.12.1`; ELF64 program-header inspection confirms `DYNAMIC` lies in a writable `LOAD` and the `LOAD` virtual-memory intervals do not overlap. The live dashboard TUI was not started; no activation was requested.
- **Exercised (2026-10-23):** without the override `hermes-tui` (i9wi8laf) failed with `Segmentation fault (core dumped) npm config set offline true`, and the pinned node segfaulted on `--version`. Patching the pristine tarball by hand with only the patchelf version or order changed: interpreter then RPATH segfaults with 0.18.0-unstable and 0.19.2 and runs with 0.15.2 and patchelf master 3e996dbe; RPATH then interpreter, or either change alone, runs with 0.19.2. With the override node runs `--version`, npm 12.0.2 runs on it, `DYNAMIC` sits in a one-page RW `LOAD` at `0x3ff000` ending where the next `LOAD` starts, the Hermes service package builds (TUI, web, wrapper), `hermes --version` runs on `HERMES_NODE`, and the full Vesta toplevel builds. The pinned uv, ffmpeg and ripgrep run without the override. The dashboard TUI wasn't started on Vesta.
- **Superseded review (2026-11-06):** `candidate`. Full Vesta selects Hermes input `2bd378ed` (`v0.23.0`), whose [pm-packages.nix](https://github.com/NousResearch/hermes-agent/blob/2bd378ed1b8d6bf2192cb26e0a55ff3091e6bd19/nix/pm-packages.nix#L55-L88) already backports [patchelf #672](https://github.com/NixOS/patchelf/pull/672) (`59acc3d9`, merged as `3e996dbe`) and puts that patched patchelf first in upstream Node inputs. Live Hermes main `b2e4ded5` retains it. The selected Node `26.12.1` derivation has local patchelf `0.15.5` followed by upstream patched `0.19.2`; derivation inspection confirms the latter contains `patchelf-fix-executable-header-load-overlap.patch`. Root `1d060086` still selects plain `0.19.2`, which compares behind the merge by 2 commits. Latest patchelf [0.19.3](https://github.com/NixOS/patchelf/releases/tag/0.19.3) contains the fix (ahead 21, behind 0), but that release is not selected. Upstream's backport makes the old local pin redundant in source; removing it still needs the unoverridden `node --version`, non-overlapping ELF mapping, Vesta build and dashboard TUI runtime checks. The evaluated Hermes wrapper reports version `0.0.0` because its Nix input metadata is not passed as a version; do not confuse that with its resolved input tag.

#### `snowfall-flake-utils-plus-deferred-config`

- **Review (2026-11-15):** `required`. Nothing changed since November 6: Snowfall `6ee3542c` still equals live main and selects the local wrapper based on `3542fe91`. [Live flake-utils-plus a00f6f51 still eagerly evaluates host config](https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/a00f6f51907b5c74d2fde086b10b19d446d15717/lib/mkFlake.nix#L113-L155); open/unmerged [#163](https://github.com/gytis-ivaskevicius/flake-utils-plus/pull/163) still injects external nixpkgs.pkgs. The selected-upstream equivalence gate remains unmet.

- **Where:** `flake.nix` (`flake-utils-plus-fixed` input; `snowfall-lib.inputs.flake-utils-plus.follows`), `vendor/flake-utils-plus-fixed/flake.nix`, `vendor/flake-utils-plus-fixed/lib/mkFlake.nix`, `vendor/flake-utils-plus-fixed/lib/options.nix`.
- **Why:** upstream `mkFlake` pre-evaluates `hostConfig` and forces `nixpkgs.config = mkForce {}`, breaking host `nixpkgs.config`. The wrapper (based on upstream 3542fe91) passes channel config/overlays as NixOS module definitions, keeps raw channel data in `__flakeUtilsPlus`, and migrates `nix.nixPath` to `nix.settings.nix-path`.
- **Upstream:** [flake-utils-plus#162](https://github.com/gytis-ivaskevicius/flake-utils-plus/issues/162); [#163](https://github.com/gytis-ivaskevicius/flake-utils-plus/pull/163) open, unmerged (head 10d81075), and **not equivalent**: it injects external `nixpkgs.pkgs` and documents that host `nixpkgs.config` still fails. Master a00f6f51 still has the eager evaluation. Snowfall main is the pinned 6ee3542c ([snowfallorg/lib#173](https://github.com/snowfallorg/lib/issues/173), maintainer call).
- **Remove when:** a selected upstream supports host `nixpkgs.config`, channel overlays/config, registry/input linking and `nix.settings.nix-path`. Then retarget the follows and delete the vendor tree. Merging #163 alone is insufficient; do not move host package policy into a new workaround to accommodate it.
- **Validate:** `all`; runtime (VM/host): Nix registry, input symlinks, `NIX_PATH`, representative overlaid packages.
- **Origin:** 26bbf25b (2026-08-09).

#### `ksa-unmerged-nixpkgs-package`

- **Review (2026-11-15):** `required`. Nothing changed in the removal assessment since November 6. [Nixpkgs #492242](https://github.com/NixOS/nixpkgs/pull/492242) remains open/unmerged, with head `670a3617` equal to the selected fork. Root d5cc6833 still lacks KSA, while full Ceres selects the [fork's 2026.5.7.4397 package](https://github.com/Leha44581/nixpkgs/blob/670a36178e0aac8fc085f133ae6470f47c021686/pkgs/by-name/ks/ksa/package.nix). The root-package availability gate remains unmet.

- **Where:** `flake.nix` (`nixpkgs-ksa`), `overlays/sgiath/default.nix` (`pkgs-ksa`, `ksa`), consumer `modules/home/gaming/role.nix`.
- **Why:** Kitten Space Agency is not in root nixpkgs; the fork branch packages 2026.5.7.4397.
- **Upstream:** [NixOS/nixpkgs#492242](https://github.com/NixOS/nixpkgs/pull/492242) open, unmerged; head equals the pinned 670a3617.
- **Remove when:** root nixpkgs has `ksa` at the needed version with equivalent runtime deps; remove input, import and overlay attr together. Keep it gaming-only (not on Pallas).
- **Validate:** `ceres` plus `.#nixosConfigurations.ceres.pkgs.ksa`; runtime: game reaches playable state.

#### `bird-unavailable-upstream-vendoring`

- **Review (2026-11-15):** `unknown`. Full Ceres still selects vendored Bird `0.8.0`. Unauthenticated [API](https://api.github.com/repos/steipete/bird) and [web](https://github.com/steipete/bird) fetches of the original upstream both return HTTP 404; deleted versus private remains unknown. Immutable public mirrors exist, including [Oceanswave 90ead61c](https://github.com/Oceanswave/bird/tree/90ead61c96d1794dfa7a4563f66f04cbaffd263f) and [transitive-bullshit 978d1779](https://github.com/transitive-bullshit/bird/tree/978d17794d8b7888d153f6d8f838327ed4951009), but no successor preserving the locally modified CLI and native open-Chromium cookie behavior was established. Retain vendoring and the deliberate bird-product decisions. No Bird execution, cookie access, build or authenticated check occurred.

- **Where:** `vendor/bird/`, `packages/bird/default.nix` (builds from `vendor/bird`).
- **Why:** upstream is unreachable; the vendored 0.8.0 tree is also locally modified (native Linux Chromium cookie source, dependency refresh, e.g. d9fce644).
- **Upstream:** [steipete/bird](https://github.com/steipete/bird) returned HTTP 404 from the API and the web (deleted vs private unknown).
- **Remove when:** a fetchable immutable upstream preserves all current CLI behavior and the native open-Chromium cookie reading (see deliberate group `bird-product`). Compare against the local tree, not the version string.
- **Validate:** `ceres`, `vesta` plus `pkgs.sgiath.bird`; runtime: `bird --help`; an authenticated read only with explicit authorization, never printing credentials.

### ComfyUI (Ceres)

Common runtime check for every ComfyUI record: `systemctl show comfyui.service -p ActiveState -p ExecStart`, `GET http://127.0.0.1:8188/system_stats` and `/object_info`, then run both seeded Qwen workflows (`int8.json`, `int8-enhanced.json`) to completion. Eval/import success is not image-generation proof. Overlay/platform changes also need `juno1` to prove the x86-only code stays lazy.

#### `comfyui-rocm-int8-probe`

- **Review (2026-11-15):** `dormant`. No configured host enables ComfyUI. Retained ROCm ComfyUI is now `0.44.0`/`2c75dc1b`; its [unpatched capability function](https://github.com/Comfy-Org/ComfyUI/blob/2c75dc1b379a59e0880619d029607af5169a62ef/comfy/model_management.py#L2101-L2120) still lacks the probe, while the fetched local patched source contains it. The torch `2.10.0+rocm7.1` constraint is unchanged; removal still needs gfx1030 GEMM and workflow proof plus the Ceres/Juno1 validation profile.

- **Where:** `overlays/comfyui/default.nix` (`applyPatches` override), `overlays/comfyui/rocm-int8-compute.patch`.
- **Why:** PyTorch 2.10.0+rocm7.1 lacks the hipBLASLt gfx1030 Tensile library. The patch probes `torch._int_mm` once per AMD device in `supports_int8_compute`, caching `False` on `RuntimeError` so ComfyUI uses its existing dequantized full-precision path; CPU and non-AMD paths are not probed.
- **Upstream:** `supports_int8_compute` has no ROCm probe in ComfyUI 0.37.0 ([73c9bad4](https://github.com/Comfy-Org/ComfyUI/blob/73c9bad4d21e7addbe1d13bc92eee0f1431b017d/comfy/model_management.py#L2049-L2065)), 0.38.0, latest release 0.39.0 or master [0df64eb2](https://github.com/Comfy-Org/ComfyUI/blob/0df64eb242b7c5759c3e86afd5d1846d923b1033/comfy/model_management.py#L2082-L2098) (excludes only MPS, XPU, DirectML, ixuca). [#16130](https://github.com/Comfy-Org/ComfyUI/pull/16130) and [#16285](https://github.com/Comfy-Org/ComfyUI/pull/16285) are related, not equivalent. No ROCm `_int_mm` issue found (search absence is not proof). comfyui-nix main = latest release = pin 58f91b00 (v0.37.0-r1).
- **Remove when:** the selected comfyui-nix package contains an equivalent capability check, or its selected ROCm wheel runs INT8 GEMM on gfx1030. Inspect the fetched/patched source and actual wheel. Cut over the package construction, service selection and `json-repair` together.
- **Validate:** `ceres` + `juno1`; runtime: with packaged Python, `torch._int_mm` and `supports_int8_compute` for `cuda:0` and `cpu`, then both workflows without HIPBLAS errors.
- **Exercised (2026-10-01):** deployed packaged Python reported gfx1030; native probe hit missing `TensileLibrary_lazy_gfx1030.dat`/`HIPBLAS_STATUS_INVALID_VALUE`; GPU `False` (cached), CPU `True`. No image generated.

#### `comfyui-python-package-set`

- **Review (2026-11-15):** `dormant`. No configured host enables ComfyUI. Retained comfyui-nix `a78b8b01` uses nested nixpkgs `f4a03c00` and its [backend Python overrides](https://github.com/utensils/comfyui-nix/blob/a78b8b018dc808c2f2c7bbe72a857a96a8b2ab04/nix/python-overrides.nix): Python `3.12.16`, torch `2.10.0+rocm7.1`, torchvision `0.25.0`, torchaudio `2.10.0`, json-repair `0.64.1`. The private-construction rationale is unchanged; root-scope compatibility and workflow proof remain absent.

- **Where:** `overlays/comfyui/default.nix` (`import comfyui-nix.inputs.nixpkgs`, upstream `versions.nix`, `python-overrides.nix`).
- **Why:** builds with comfyui-nix's own nixpkgs (dc5d91f8), not root nixpkgs, so upstream Python overrides (Python 3.12, torch 2.10.0+rocm7.1) still match and unchanged derivations share store paths.
- **Upstream:** [python-overrides.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/nix/python-overrides.nix); [comfyui-nix#81](https://github.com/utensils/comfyui-nix/issues/81) closed 2026-08-14, which does not prove root-nixpkgs compatibility.
- **Remove when:** the local source patch no longer needs a private package construction (prefer upstream package + `withExtraPythonPackages`), or root pkgs is proven compatible for the full GPU Python scope with no duplicate torch stack. Keep `json-repair` and ROCm library order.
- **Validate:** `ceres` + `juno1`; runtime: import torch/torchvision/torchaudio/json_repair from the service Python, ROCm device visible, both workflows.

#### `comfyui-open-clip-broken-allowance`

- **Review (2026-11-15):** `dormant`. No configured host enables ComfyUI. The retained Python scope still selects open-clip-torch `3.3.0` with `meta.broken = false`; its [selected nixpkgs recipe](https://github.com/NixOS/nixpkgs/blob/f4a03c008967841f2a0b3cb7c436fc6fc31671f6/pkgs/development/python-modules/open-clip-torch/default.nix) has no broken declaration. The allowance remains apparently inert, unchanged from the previous review; removal still awaits a Ceres build without it, import and workflow proof on enablement.

- **Where:** `overlays/comfyui/default.nix` (`allowBrokenPredicate` for `open-clip-torch`).
- **Why:** the private package set marks `open-clip-torch` broken; this mirrors upstream comfyui-nix ([flake.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L177-L184), tests disabled in [python-overrides.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/nix/python-overrides.nix#L954-L959)). Not an insecure-package exemption.
- **Remove when:** the selected nixpkgs/Python scope builds `open-clip-torch` without the predicate, or the closure no longer contains it. Upstream dropping its own exception is a prompt to check, not proof.
- **Validate:** `ceres`; runtime: `import open_clip` from service Python, both workflows.

#### `comfyui-service-overlay-selection`

- **Review (2026-11-15):** `dormant`. Ceres disables ComfyUI and has no service ExecStart. On enablement the local selection remains needed: [pinned comfyui-nix](https://github.com/utensils/comfyui-nix/blob/a78b8b018dc808c2f2c7bbe72a857a96a8b2ab04/flake.nix#L371-L382) supplies its own packageSet, bypassing the retained patched ROCm package and json-repair. The coordinated-cutover gate is unchanged and unmet; service selection and both workflows need verification when enabled.

- **Where:** `modules/nixos/services/comfyui.nix` (`package = pkgs.comfy-ui-rocm`).
- **Why:** upstream module defaults `packageSet` to the flake's own packages ([flake.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L348-L357)), which would bypass the INT8 patch and `json-repair`. Upstream `extraPythonPackages` cannot be combined with a custom package.
- **Remove when:** the default package already contains the INT8 fix; migrate `json-repair` to `services.comfyui.extraPythonPackages` in the same cutover.
- **Validate:** `ceres`; inspect evaluated `ExecStart` package; runtime: enhancer nodes registered, both workflows.

#### `comfyui-rocm-platform-guard`

- **Review (2026-11-15):** `dormant`. No configured host enables ComfyUI; Juno1 toplevel evaluation succeeds. [Selected comfyui-nix `a78b8b01`](https://github.com/utensils/comfyui-nix/blob/a78b8b018dc808c2f2c7bbe72a857a96a8b2ab04/flake.nix#L350-L361) still restricts ROCm to x86_64 Linux, and the retained wheel is manylinux x86_64. The architecture constraint is unchanged; retain the guard and validate Ceres/Juno1 on enablement.

- **Where:** `overlays/comfyui/default.nix` (`isLinux && isx86_64` branch, `prev.comfy-ui-rocm` fallback).
- **Why:** upstream ROCm package exists only on x86_64 Linux ([flake.nix](https://github.com/utensils/comfyui-nix/blob/58f91b001c99a97df46b7be8d58b08f01cb8f6ff/flake.nix#L332-L337)); keeps aarch64 (Juno) evaluation lazy.
- **Remove when:** upstream supports ROCm on another architecture and that platform's wheels are proven; do not enable Ceres's ROCm service on aarch64 because generic ComfyUI supports it.
- **Validate:** `ceres` + `juno1`.

#### `comfyui-qwen-memory-policy`

- **Review (2026-11-15):** `dormant`. Ceres disables ComfyUI, so its evaluated arguments are empty; the gated source retains the 5 GiB reserve and both seeded workflows retain CPU placement of the regular encoder. The [exact model revision `ace0edeb`](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/tree/ace0edeb3791a594ddfa36ed5f41a178a394e921) remains fetchable. The hardware-fit rationale is unchanged; no cold/warm baseline/enhanced memory proof supports removing the policy.

- **Where:** `systems/x86_64-linux/ceres/qwen-image.nix` (VRAM reserve), `systems/x86_64-linux/ceres/qwen-image/int8.json`, `int8-enhanced.json` (CPU text encoder placement).
- **Why:** 5 GiB VRAM reserve for casts/attention scratch on the 16 GiB RX 6950 XT and CPU placement of the Qwen3VL encoder, needed with INT8 storage + full-precision fallback.
- **Upstream:** [Qwen-Image-2.1 ace0edeb](https://huggingface.co/Comfy-Org/Qwen-Image-2.1/tree/ace0edeb3791a594ddfa36ed5f41a178a394e921) and the ComfyUI revisions above. Hardware fit, not an upstream bug.
- **Remove when:** the selected model/kernel/memory management fits both workflows cold and warm (including enhancer load transitions) without the reserve or CPU placement. Update seeded and saved workflows consistently.
- **Validate:** `ceres`; runtime: 1024×1024 baseline and enhanced workflows with memory observation.

### Desktop and graphics

#### `desktop-hyprland-mesa-abi`

- **Review (2026-11-15):** `required`. Full Ceres and Pallas now select Hyprland-scope Mesa 26.2.6 for both architectures, while [root nixpkgs d5cc6833](https://github.com/NixOS/nixpkgs/tree/d5cc6833999746cffdfe0598f7bc801a57b887a9) selects Mesa 26.3.0; the previous identical-output evidence no longer holds. [Selected Hyprland 11cbc6c5](https://github.com/hyprwm/Hyprland/tree/11cbc6c577b84ffb1edf4df3fc5b6128c3ae6947) uses nixpkgs f4a03c00. Root, compositor and portal glibc paths agree, but no current incompatibility or successful removal runtime was demonstrated. Retain the coherent Mesa selection pending desktop builds and acceleration, capture and 32-bit-game checks.

- **Where:** `modules/nixos/desktop/wayland.nix` (`hardware.graphics.package`/`package32` from `inputs.hyprland.inputs.nixpkgs`); enabled by `modules/nixos/hardware/gpu.nix`. README "Desktop graphics" explains the failure.
- **Why:** root Mesa can require a newer glibc than the pinned compositor loads, causing `Cannot open backend: no allocator available` (5299bbf2). Evaluated 2026-10-10: selected Mesa 26.1.5 with Hyprland's glibc 2.42 vs root Mesa 26.2.4 / glibc 2.44.
- **Upstream:** [Hyprland on NixOS (0.54)](https://wiki.hypr.land/0.54.0/Nix/Hyprland-on-NixOS/) still recommends Mesa from Hyprland's nixpkgs. [hyprwm/Hyprland#5148](https://github.com/hyprwm/Hyprland/issues/5148) is closed (2024-03-17), not proof for the current pins.
- **Remove when:** compositor, portal and 64/32-bit Mesa share a coherent package universe (e.g. Hyprland follows root nixpkgs, or its nixpkgs equals root) and the session runs without the override.
- **Validate:** `desktop`; runtime: running Hyprland and `/run/opengl-driver` paths, no loader/GLIBC errors in journal, accelerated rendering, screen sharing; on Ceres a 32-bit Steam/Proton game.

#### `legacy-wlroots-session-flags`

- **Review (2026-11-15):** `unverified`. Both flags remain exported, and neither occurs in [selected Hyprland 11cbc6c5 src](https://github.com/hyprwm/Hyprland/tree/11cbc6c577b84ffb1edf4df3fc5b6128c3ae6947/src). The material conclusion is unchanged: no original failure or complete inventory of other session consumers is established. Retain pending that inventory and AMD/NVIDIA cursor, rendering, hotplug and capture checks without each flag.

- **Where:** `modules/nixos/desktop/wayland.nix` (`WLR_RENDERER_ALLOW_SOFTWARE`, `WLR_NO_HARDWARE_CURSORS`).
- **Why:** legacy wlroots software-render/cursor flags; neither name occurs in pinned Hyprland `src/`. Possibly stale, but other consumers are not ruled out.
- **Upstream:** [selected Hyprland source](https://github.com/hyprwm/Hyprland/tree/5c9377c15f85c50648f35ca5a213754f95b93ca0/src) has no consumer found for either flag; [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots) remains a possible consumer family. No original failure or fixed revision is identified.
- **Remove when:** actual session consumers are inventoried and cursors/rendering work without each flag on AMD and NVIDIA.
- **Validate:** `desktop`; runtime: login, cursor movement and capture, monitor hotplug, wlroots-based apps.

#### `satty-floating-hack`

- **Review (2026-11-15):** `required`. Nothing material changed: selected/latest Satty [0.22.0/9f99065e](https://github.com/Satty-org/Satty/blob/9f99065e4177820e965f5475503e5c3bdbd74e6a/cli/src/command_line.rs#L36-L39) and [live main 7e38860d](https://github.com/Satty-org/Satty/blob/7e38860dfc6ea426e7e2c9f729dbd00ec794bed0/cli/src/command_line.rs#L54-L57) still declare the floating hack. Window-rule-only region and monitor flows remain untested; retain the flag and rule.

- **Where:** `modules/home/desktop/hyprland/screenshot.nix` (`--floating-hack` plus window rule for `com.gabm.satty`).
- **Why:** Satty's own compositor-dependent floating workaround ([command_line.rs](https://github.com/Satty-org/Satty/blob/f578432a68f3930cc5fd52f2f7d99d54aff0d9ae/cli/src/command_line.rs#L36-L39), still on main); selected Satty 0.22.0.
- **Remove when:** the window rule alone floats Satty for both region and monitor flows.
- **Validate:** `desktop`; runtime: SUPER+S and SUPER+SHIFT+S, annotate, save, copy.

#### `quickshell-store-theme-restart`

- **Review (2026-11-15):** `unverified`. Nothing material changed: selected/latest Quickshell [0.3.2/4f508be5](https://github.com/quickshell-mirror/quickshell/blob/4f508be500dea6e5732cc3d50382a0048b17e7b1/src/io/fileview.cpp#L494-L547) and [live master 9b0f339b](https://github.com/quickshell-mirror/quickshell/blob/9b0f339b19057f4731bf3b48293307d7ef241671/src/io/fileview.cpp) retain the same watcher logic. The configured theme restart trigger remains; no atomic-symlink replacement proof in live and packaged modes establishes its removal.

- **Where:** `modules/home/desktop/quickshell.nix` (`X-Restart-Triggers`), `modules/home/desktop/quickshell/config/Theme.qml`.
- **Why:** the file watcher does not notice the store theme symlink target changing during a switch ([QFileSystemWatcher](https://doc.qt.io/qt-6/qfilesystemwatcher.html) stops watching renamed files; exact case not reproduced).
- **Remove when:** the selected watcher picks up an atomic symlink replacement in live and packaged modes.
- **Validate:** `desktop`; runtime: change theme in a disposable branch, switch, verify colors/fonts/wallpaper update without losing app windows.

#### `quickshell-hyprland-workspace-address`

- **Review (2026-11-15):** `required`. The defect is unchanged: selected Quickshell [4f508be5 activate()](https://github.com/quickshell-mirror/quickshell/blob/4f508be500dea6e5732cc3d50382a0048b17e7b1/src/wayland/hyprland/ipc/workspace.cpp#L165) dispatches the display name and both events resolve by name; [live master 9b0f339b](https://github.com/quickshell-mirror/quickshell/blob/9b0f339b19057f4731bf3b48293307d7ef241671/src/wayland/hyprland/ipc/connection.cpp) retains them. Selected Hyprland [0.57.2/11cbc6c5](https://github.com/hyprwm/Hyprland/blob/11cbc6c577b84ffb1edf4df3fc5b6128c3ae6947/src/desktop/state/FocusState.cpp#L283-L287) still emits workspace addresses. Retain the patch; no new runtime evidence supersedes November 1.

- **Where:** `packages/quickshell/default.nix` (`overrideAttrs` under the multimedia wrapper), `packages/quickshell/hyprland-workspace-address.patch`.
- **Why:** Hyprland 0.57 separates a workspace's address from its display name: workspace 8 has address `8` and name `firefox`. Quickshell's `HyprlandWorkspace.activate()` dispatches the name, which Hyprland resolves to a new workspace with address `firefox`. `focusedmon` and `openwindow` carry the address, but Quickshell looks it up among names, so a named workspace loses its focus state after a monitor change and a new window on it has a null workspace. The patch dispatches the same selector as Hyprland's `Workspace::selector()` and looks both events up by address. QML can't repair the built-in `HyprlandToplevel.workspace`, so the fix is in the package. It rebuilds Quickshell instead of using the binary cache.
- **Not changed:** `movewindowv2`, `createworkspacev2` and `j/clients` still match on the name; moved windows and startup pass with distinct names, and duplicate names are untested. Selected 0.3.2 ignores `changeworkspaceid`, so `activate()` uses the old address after an id change until Quickshell restarts; master handles that event.
- **Upstream:** [quickshell-mirror/quickshell#1119](https://github.com/quickshell-mirror/quickshell/issues/1119) (closed 2026-09-21) added address tracking. No issue or PR for these three defects (searched 2026-11-01). Master 9b0f339b has the same `activate()`, `focusedmon` and `openwindow` code.
- **Selected pin:** root nixpkgs 1c89083e, Quickshell v0.3.2 (latest release), Hyprland v0.57.0. Hyprland posts `addressableName()` in `focusedmon` (`src/desktop/state/FocusState.cpp`) and `openwindow` (`src/desktop/view/window/Window.cpp`).
- **Remove when:** the selected Quickshell's `activate()` dispatches an address-based selector and both events resolve by address. Remove the patch and `overrideAttrs`; keep the multimedia wrapper. A patch that no longer applies fails the build and means this review is due.
- **Validate:** `desktop`; `nix build --no-link --no-update-lock-file .#quickshell`. Runtime: activating a renamed workspace selects its numeric address and creates no workspace; after a monitor focus round trip the renamed workspace stays focused; a new window on it reports that workspace.
- **Exercised (2026-11-01):** against live Hyprland 0.57.0, production `rail/Workspaces.qml` under unpatched Quickshell failed all three checks (selected address `firefox`, highlight false, workspace null); moved-window, scratchpad, unnamed-click and rail checks passed. All seven pass on the patched package with no workspace left behind. Full Ceres and Pallas system builds passed. Activated Ceres and verified its installed service runs the patched executable; rails, ignored-output behavior and launcher open/close on both configured monitors passed. Returned to Noctalia after testing; Pallas was not activated.

#### `hex-model-service-selection`

- **Review (2026-11-15):** `required`. Selected Hex advanced to 3.4.0/[82ca73f9](https://github.com/anomalyco/hex/blob/82ca73f945db65dfd82e980aa4ff4632f7055fcd/nix/hm-module.nix#L31), but its module and [live dev 77b474d7](https://github.com/anomalyco/hex/blob/77b474d7abc2799a6b0246849a952a07a635abbd/nix/hm-module.nix#L31) retain bare `model install` and settings activation after reloadSystemd. Full Ceres still explicitly requests Whisper large-v3-turbo and English. The ordering defect is unchanged; retain the override pending an upstream fix and first-activation proof.

- **Where:** `modules/home/desktop/hex.nix` (`systemd.user.services.hex-model.Service.ExecStart` forced to `hex model install <model> --language <language>` from `programs.hex.model` and `programs.hex.language`).
- **Why:** upstream's `hex-install-model` runs a bare `hex model install`, which reads the model from settings. The `hex-model` service starts during `reloadSystemd`, but `home.activation.hexSettings` applies `programs.hex.model` only after it, so a first install with no settings file downloads Hex's default Parakeet Unified English (731 MB) instead of the declared model. The override names the model and language, so ordering no longer matters. It drops upstream's two-minute wait for `network-online.target`; `Restart=on-failure` with `RestartSec=60` stays, so a login without network retries.
- **Upstream:** no issue or PR (searched 2026-10-31; `docs/nix.md` promises the "selected model"). `dev` b16587bc still runs the bare command in `nix/hm-module.nix` (line 31).
- **Selected pin:** hex 154b4d40, the same bare command in `nix/hm-module.nix` with `hexSettings` at `entryAfter [ "reloadSystemd" ]`; `src/control/cli.rs` `install_model` takes the optional model and `--language`.
- **Remove when:** the selected module's generated `hex-model` command requests the declared model on an empty support directory, or applies settings before the service starts. Remove the `ExecStart` override and the `inherit` entries only it uses.
- **Validate:** `desktop`; evaluate `home-manager.users.sgiath.systemd.user.services.hex-model.Service.ExecStart` through `nixosConfigurations.ceres`, then run it with an empty `HEX_APPLICATION_SUPPORT_DIR` and a blocked `HTTPS_PROXY`: it must print `Installing Whisper large-v3-turbo` and exit non-zero. Runtime: on a first activation `hex-model` installs that model and `hex model status` reports it installed.
- **Exercised (2026-10-31):** with an empty support directory and a proxy on `127.0.0.1:9`, upstream's generated `hex-install-model` printed `Installing Parakeet Unified English (731 MB)`; the evaluated Ceres command printed `Installing Whisper large-v3-turbo` and failed at the proxy with a non-zero exit, which is what `Restart=on-failure` retries. No model was downloaded and the unit was not activated.

### Gaming (Ceres)

#### `gaming-gtk2-broken-allowance`

- **Review (2026-11-15):** `required`. Root nixpkgs is now `d5cc6833`; GTK2 `2.24.33` still has [problems.broken](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/pkgs/by-name/gt/gtk2/package.nix#L178-L184), and [Zulu8’s runtime dependencies](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/pkgs/development/compilers/zulu/common.nix#L52-L62) still include it. Lutris continues to omit GTK2. The previous review’s remaining Zulu8 constraint is unchanged; removal tracking remains open and targets migration before NixOS 27.05.

- **Checked (2026-11-18):** root `1a08097f` Lutris no longer lists `gtk2` (only `gtk3`/`gtk4`); without the handler Ceres evaluation now stops on `gtk+-2.24.33` through `prismlauncher-12.0-unstable-2026-11-16` -> `zulu-ca-jdk-8.0.492`. `zulu8` is the only remaining consumer. The handler only warns while something evaluates GTK2, so a Ceres evaluation without the GTK2 warning means it is removable. Building Prism's `zulu8` with `gtkSupport = false` (as Vesta's server does) would remove the need, at the cost of the GTK look and feel in AWT/Swing windows; that is an owner decision, not made here.

- **Where:** `modules/nixos/gaming/role.nix` (`nixpkgs.config.problems.handlers."gtk+".broken = "warn"`), so only hosts with the gaming role get it.
- **Why:** selected nixpkgs marks GTK2 `problems.broken` as a removal notice, not a build failure (`pkgs/by-name/gt/gtk2/package.nix` lines 178-184: final release 2.24.33, migrate before NixOS 27.05). Prism Launcher's `zulu8` (Nomifactory) adds `gtk2` because `gtkSupport` defaults on for JDK < 17 (`pkgs/development/compilers/zulu/common.nix` lines 26, 60-61). Without the handler, Ceres evaluation stops on `gtk+-2.24.33` in `zulu-ca-jdk-8.0.492` (see Checked above; before root `1a08097f` it stopped in Lutris's FHS env, which then listed `gtk2`). The handler matches only package `gtk+` and problem `broken`; every other broken package still fails, and each evaluation prints the GTK2 warning. Not an `allowBroken` or insecure-package exemption. Vesta's headless Nomifactory server avoids GTK2 with `zulu8.override { gtkSupport = false; }` instead (`modules/nixos/server/minecraft.nix`).
- **Upstream:** [NixOS/nixpkgs#410814](https://github.com/NixOS/nixpkgs/issues/410814) (GTK2 removal tracking) open on 2026-11-03.
- **Selected pin:** root nixpkgs `1a08097f`; `gtk+` 2.24.33, `zulu-ca-jdk-8.0.492`; Lutris without `gtk2`.
- **Remove when:** Prism's `zulu8` no longer pulls `gtk+` (dropped, built without GTK, or no longer needed) and nothing else does: Ceres evaluates without the GTK2 warning. If nixpkgs removes `gtk2` first, this handler stops helping and Ceres evaluation fails on the missing attribute; replace the dependency then.
- **Validate:** `all` (toplevel drvPath evaluation for every host proves the scope; Ceres must evaluate with only the GTK2 warning); `ceres` build. Runtime: start Lutris and a Nomifactory instance in Prism with `zulu8`.

### Terminal, agents and services

#### `hermes-agent-home-mode`

- **Review (2026-11-15):** `required`. Selected Hermes input [3b421578](https://github.com/NousResearch/hermes-agent/tree/3b421578588243f920886e6fe79a6faa87ea026e) still sets HERMES_HOME to 2770 in [tmpfiles](https://github.com/NousResearch/hermes-agent/blob/3b421578588243f920886e6fe79a6faa87ea026e/nix/nixosModules.nix#L447) and [activation](https://github.com/NousResearch/hermes-agent/blob/3b421578588243f920886e6fe79a6faa87ea026e/nix/nixosModules.nix#L467). Its [discovery policy](https://github.com/NousResearch/hermes-agent/blob/3b421578588243f920886e6fe79a6faa87ea026e/hermes_cli/gateway_runtime_discovery.py#L50) permits group write only for the owner’s private group; full Vesta config uses `sgiath:hermes` while sgiath’s primary group is `users`. Live main `01129483` has identical relevant files. Retain both 0700 corrections. No production permissions, gateway state or authenticated operation was inspected.

- **Where:** `modules/nixos/services/hermes-agent.nix` (activation script `hermes-agent-home-mode` after `hermes-agent-setup`, tmpfiles `z` rule; both set `/home/sgiath/hermes/.hermes` to 0700).
- **Why:** the upstream NixOS module makes HERMES_HOME 2770 owned by `sgiath:hermes`, in `hermes-agent-setup` on every activation and in its tmpfiles `d` rule on boot and switch. Hermes' own gateway discovery (`home_mode_unsafe` in `hermes_cli/gateway_runtime_discovery.py`) only accepts a group-writable home when the group is the owner's private group, so `connect_gateway()` fails with `unsafe_control_permissions` and cron jobs that need the gateway (the Oct 24 and 25 screenshot runs) die with `GatewayUnavailableError`. Both services run as `sgiath` and nothing else needs group access to the home, so 0700 is enough. `stateDir`, `workspace` and the state subdirectories stay 2770; discovery doesn't check them.
- **Upstream:** no issue or PR filed for this workaround. Main still sets the tmpfiles rule and the activation `chmod 2770` ([nixosModules.nix](https://github.com/NousResearch/hermes-agent/blob/main/nix/nixosModules.nix), checked 2026-10-25).
- **Selected pin:** hermes-agent bf0203a7, [nixosModules.nix#L446](https://github.com/NousResearch/hermes-agent/blob/bf0203a794a07aac3ff764972ab9087baa4e4f4e/nix/nixosModules.nix#L446) (tmpfiles `d ... 2770`) and [#L466](https://github.com/NousResearch/hermes-agent/blob/bf0203a794a07aac3ff764972ab9087baa4e4f4e/nix/nixosModules.nix#L466) (`chmod 2770`); [gateway_runtime_discovery.py#L50](https://github.com/NousResearch/hermes-agent/blob/bf0203a794a07aac3ff764972ab9087baa4e4f4e/hermes_cli/gateway_runtime_discovery.py#L50) rejects the result.
- **Remove when:** the selected module leaves HERMES_HOME in a mode discovery accepts (or discovery accepts the module's mode) in both activation and tmpfiles. Remove the activation script and the `z` rule together.
- **Validate:** `vesta`; after switch and after boot `stat -c %a /home/sgiath/hermes/.hermes` is `700` and `connect_gateway()` reaches the gateway. Runtime: authenticate with `connect_gateway()` and query `cron.recover` for a nonexistent job/request; expect `status: missing` without submitting a job or sending a message.
- **Exercised (2026-10-25):** on the pinned module the activation mode commands and the tmpfiles rule both left the fixture home 2770, which the deployed discovery policy rejected with `unsafe_control_permissions`. The full Vesta NixOS build passed and was deployed as `/nix/store/yrdnwi92nz026jc7g7dg8a9j1mx1plnm-nixos-system-vesta-26.11.20261023.3ec6363`. Its ordered activation and two tmpfiles fixture runs passed the real discovery policy. On Vesta, `.hermes` stayed 0700 after switch and another tmpfiles run, the same gateway PID remained active, and an authenticated `cron.recover` probe returned `status: missing` without submitting work. All six job schedules matched their pre-switch fingerprint. Scheduled digest execution itself was not replayed.

#### `pihole-first-run-setup-retry`

- **Review (2026-11-15):** `required`. Vesta now selects FTL 6.9, but [root d5cc6833 setup](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/nixos/modules/services/networking/pihole-ftl-setup-script.nix) remains byte-identical to [live master 605e90c7](https://github.com/NixOS/nixpkgs/blob/605e90c7bd301d1a28f9a277d82818f1c972bc94/nixos/modules/services/networking/pihole-ftl-setup-script.nix): API availability is retried, database reopening and list submission are not. The defect is unchanged. Both Vesta and Hygiea configure the local retry; no disposable fresh-state or populated-state runtime proof was run.

- **Where:** `modules/nixos/services/pi-hole.nix` (`pihole-ftl-setup` `Restart=on-failure`, `RestartSec=5`).
- **Why:** on fresh state the upstream setup script creates `gravity.db`, signals FTL and posts lists immediately; the first request can fail "Database not available".
- **Upstream:** pinned [pihole-ftl-setup-script.nix](https://github.com/NixOS/nixpkgs/blob/e7439b6b14ad3cc35d05608ebca9bce01a25f5f8/nixos/modules/services/networking/pihole-ftl-setup-script.nix#L76-L95) still only probes API availability, not database reopen. No upstream issue/fix known.
- **Remove when:** the selected setup script waits for database readiness (or retries list submission) and a disposable fresh-state run provisions all lists without the retry. Never reset production Pi-hole state to test.
- **Validate:** `vesta`; runtime: disposable fresh-state setup succeeds, lists exist, DNS resolves; populated-state rerun stays idempotent.

#### `pihole-module-src-tag`

- **Where:** `modules/nixos/services/pi-hole.nix` (`services.pihole-ftl.piholePackage` is `pkgs.pihole` with `passthru.src.src` added, under `lib.mkIf` on the selected module file still containing `piholePackage.src.src.tag`; otherwise the module default).
- **Why:** the module writes `CORE_VERSION=${cfg.piholePackage.src.src.tag}` into `/etc/pihole/versions`, but pihole 6.6's `passthru.src` is its `fetchFromGitHub` source itself, so evaluation of Vesta and Hygiea fails with `attribute 'src' missing`. The override adds the missing level and keeps `src.tag`, so it also works with the fixed module.
- **Upstream:** [NixOS/nixpkgs#588606](https://github.com/NixOS/nixpkgs/pull/588606) ("modules/pihole: fix typo (double `src`)") merged to master 2026-11-15 as `fa4eeb80`.
- **Selected pin:** root `1a08097f` is behind that merge by 303 commits (compare `fa4eeb80...1a08097f`: `behind`); its `nixos/modules/services/networking/pihole-ftl.nix` line 510 still reads `src.src.tag`. `nixpkgs-master` `41d31f02` has the fix, and the guard reads false against its module.
- **Remove when:** the guard is false (the selected module no longer contains the typo); remove the `piholePackage` setting and the `moduleReadsSrcSrc` binding.
- **Validate:** `vesta` and Hygiea toplevel evaluation; `/etc/pihole/versions` names the pihole tag.
- **Exercised (2026-11-18):** with `piholePackage` forced to plain `pkgs.pihole`, Vesta evaluation failed with `attribute 'src' missing`; with the guard the evaluated package is unchanged (`b1bbhax0…-pihole-6.6.drv`) and the Vesta toplevel builds.

#### `searx-json-secret-interpolation`

- **Review (2026-11-15):** `required`. Selected root nixpkgs [d5cc6833](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/nixos/modules/services/networking/searx.nix#L26) generates YAML and then substitutes environment values with `envsubst`, without runtime credential serialization. [Live master 605e90c7](https://github.com/NixOS/nixpkgs/blob/605e90c7bd301d1a28f9a277d82818f1c972bc94/nixos/modules/services/networking/searx.nix#L26) retains it. Keep local `jq --rawfile`, runtime credentials and both restart units. Full Vesta has empty favicon/limiter settings, but their generation remains part of any future cutover. No secret values, generated production settings or live search were read; fixture and runtime validation were not run.

- **Where:** `modules/nixos/services/searx.nix` (`searx-init` replaced with `jq --rawfile`).
- **Why:** upstream `envsubst` interpolates secrets unescaped into JSON strings; jq encodes them correctly while keeping runtime credentials and restart wiring.
- **Upstream:** pinned [searx.nix](https://github.com/NixOS/nixpkgs/blob/e7439b6b14ad3cc35d05608ebca9bce01a25f5f8/nixos/modules/services/networking/searx.nix#L31-L37) still uses `envsubst`. No upstream issue recorded.
- **Remove when:** the selected module serializes credential strings safely at runtime; reconcile favicon/limiter generation first; keep restart wiring. Credential handling review belongs to the security model.
- **Validate:** `vesta`; runtime: fixture with special characters round-trips, `searx-init` and SearXNG start, a search works.

#### `executor-state-ownership-migration`

- **Review (2026-11-15):** `unknown`. Full Vesta selects `ghcr.io/rhyssullivan/executor-selfhost:1.6.10`; its release tag resolves to `3890d6f5`, whose [Dockerfile](https://github.com/UsefulSoftwareCo/executor/blob/3890d6f5e5efd1530f0dba0fe23ada95a39caf86/apps/host-selfhost/Dockerfile#L41) owns `/data` as 65532:65532 and explicitly sets `USER 65532:65532`. The recursive `Z` removal gate still lacks proof that every retained volume, restored backup and supported rollback target is already correctly owned. Those production facts were deliberately not inspected. Keep both tmpfiles rules; no volume contents, ownership, container state or credentials were read or changed.

Also covers audit ID `executor-root-to-nonroot-state-migration`.

- **Where:** `modules/nixos/services/executor.nix` (tmpfiles `d` + recursive `Z` for uid/gid 65532 on `/data/executor`).
- **Why:** images up to 1.6.8 ran as root; selected 1.6.10 is distroless nonroot (`USER 65532`, [Dockerfile](https://github.com/UsefulSoftwareCo/executor/blob/3890d6f5e5efd1530f0dba0fe23ada95a39caf86/apps/host-selfhost/Dockerfile#L28)). `Z` migrates existing root-owned state; `d` stays as the ongoing rule.
- **Remove `Z` when:** every retained volume, restored backup and supported rollback target is already 65532-owned; keep the `d` rule aligned with the image UID.
- **Validate:** `vesta`; runtime: read-only owner check (`stat`/`find -not -user 65532`, no content reads), container start/restart, health and persistence.

#### `executor-registry-image-version-selection`

- **Review (2026-11-15):** `required`. Nothing material changed: full Vesta and the updater dry run remain at image 1.6.10, while GitHub’s latest release is [v1.6.11/4c753d3b](https://github.com/UsefulSoftwareCo/executor/releases/tag/v1.6.11). Its [publishing workflow](https://github.com/UsefulSoftwareCo/executor/blob/4c753d3b1c4a5c4c9d926f718c02c0622635f2f6/.github/workflows/publish-selfhost-docker.yml#L4-L10) and [live main 5d84c586](https://github.com/UsefulSoftwareCo/executor/blob/5d84c58647e3544b28347e23ac4a7b8a72c8f722/.github/workflows/publish-selfhost-docker.yml#L4-L10) still require manual dispatch. Retain registry-based version selection; no per-release image guarantee meets the removal gate.

- **Where:** `scripts/update-executor.sh` (highest semver tag on `ghcr.io/rhyssullivan/executor-selfhost`).
- **Why:** not every GitHub release publishes an image (comment: 1.6.9 had none), so the updater follows registry tags, not releases. Concrete version pinning in the module (never `:latest`) is a separate deliberate rule.
- **Upstream:** [v1.6.10](https://github.com/UsefulSoftwareCo/executor/releases/tag/v1.6.10) is latest; registry also at 1.6.10.
- **Exercised (2026-10-01):** `scripts/update-executor.sh --dry-run` → "already at 1.6.10".
- **Remove when:** upstream guarantees a matching image for every release, or the updater design changes deliberately. Matching versions today are not enough.
- **Validate:** `vesta`; runtime: deployed image tag and Executor health after switch.

#### `t3code-antigravity-mcp-config`

- **Where:** `modules/home/agents/antigravity.nix` (`home.file` links `~/.t3/userdata/providers/antigravity/<sha256("antigravity")>/config/mcp_config.json` to the same immutable store file as `~/.gemini/config/mcp_config.json` when `services.t3code.enable` and native immutable Antigravity MCP config are active; `home.activation.t3codeAntigravityMcp` runs between `writeBoundary` and `linkGeneration` to keep missing T3 private directories `0700` and drop `agy`'s empty placeholder before linking).
- **Why:** T3 Code launches `agy acp` against an isolated `--gemini-dir ~/.t3/userdata/providers/antigravity/<sha256(instanceId)>`, and `linkAntigravityUserConfig` in [`apps/server/src/provider/antigravityAuthSupport.ts`](https://github.com/pingdotgg/t3code/blob/856b105fa23f9cb9fdd49a8f102cb66a71b78265/apps/server/src/provider/antigravityAuthSupport.ts#L256-L288) symlinks only `AGENTS.md`, `GEMINI.md`, `config/skills.json`, and the two `skills` directories from `~/.gemini`, omitting `config/mcp_config.json` ("Private GEMINI_HOME isolates credentials/hooks/MCP"). T3 exposes no `homePath` or user MCP server setting for Antigravity, so T3 Antigravity threads only see the injected `t3-code` server and cannot reach Executor. Side effect: [`isAntigravityTextGenerationAvailable`](https://github.com/pingdotgg/t3code/blob/856b105fa23f9cb9fdd49a8f102cb66a71b78265/apps/server/src/textGeneration/AntigravityTextGeneration.ts#L71-L105) disables Antigravity system text generation on profiles with non-empty `mcp_config.json` (Ceres currently uses Claude for `textGenerationModelSelection` and `sourceControlWriterModelSelection`).
- **Upstream:** no issue filed; checked against nightly `0.1.12-nightly.20261123.5151` ([`856b105f`](https://github.com/pingdotgg/t3code/commit/856b105fa23f9cb9fdd49a8f102cb66a71b78265), 2026-11-23).
- **Selected pin:** `packages/t3code-nightly/sources.json` `0.1.12-nightly.20261123.5151` (`856b105f`).
- **Remove when:** T3 Code either links `~/.gemini/config/mcp_config.json` into its Antigravity profile or exposes native MCP server / profile-path configuration for Antigravity; switch to that setting and drop the `home.file` link and `t3codeAntigravityMcp` activation block.
- **Validate:** `ceres`, `pallas`, `vesta` (and `juno1` eval confirming omission when `services.t3code.enable` is false); runtime: start a new Antigravity thread in T3 Code and confirm Executor MCP tools load alongside `t3-code`.
- **Exercised (2026-11-23):** isolated `agy acp --gemini-dir <tmp> --app-data-dir antigravity-acp` with T3's env (`AGY_ACP_FORCE_FILE_STORAGE=1`, `AGY_CLI_DISABLE_AUTO_UPDATE=1`, `BROWSER=false`) and `<tmp>/config/mcp_config.json` symlinked to the Nix-generated store file completed migration, kept the symlink intact, spawned `mcp-remote`, and populated `antigravity-acp/mcp/executor/` with all 7 Executor tools. Full Ceres, Pallas and Vesta builds and Juno1 eval passed; `mutableSettings = true` and empty `mcpServers` overrides evaluated cleanly; activation snippet verified across fresh, 0-byte, empty-JSON, custom-config and symlink fixtures.

### Local packages and scripts

#### `katrain-kivy-python-api`

- **Review (2026-11-15):** `required`. Full Ceres selects KaTrain `1.20.0`, Python `3.13.18` and local Kivy `2.3.1`; root nixpkgs `d5cc6833` still supplies Python `3.14.10` and the Kivy master snapshot. [Selected KaTrain](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml#L6-L10) still requires Python <3.14. Kivy’s latest release advanced to [2.3.2](https://github.com/kivy/kivy/releases/tag/2.3.2), but it is not selected; dependency compatibility and UI/audio removal gates remain unmet.

- **Where:** `packages/katrain/default.nix` (Python 3.13 + package-local Kivy 2.3.1 with pyproject relaxations and mtdev path patch); consumer `homes/x86_64-linux/sgiath@ceres/default.nix`.
- **Why:** KaTrain 1.20.0 needs Python `>=3.11,<3.14` and Kivy 2.3.1 APIs; root nixpkgs has Kivy `2.3.1-unstable-2026-07-11`.
- **Upstream:** KaTrain latest v1.20.0 ([pyproject](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml)); Kivy latest 2.3.1; [kivy#9225](https://github.com/kivy/kivy/issues/9225) open (the local comment claiming Python 3.14 support merged is unreliable).
- **Remove when:** a selected nixpkgs dependency set satisfies KaTrain's actual Python/Kivy requirements and runs its UI/audio. Keep normal mtdev/build-dependency packaging if still needed.
- **Validate:** `ceres`; runtime: open KaTrain, load a game, UI and audio work.

#### `davinci-resolve-mcp-sdk-version`

- **Review (2026-11-15):** `required`. Full Ceres now selects Resolve MCP `5.2.11`/`f74eac02` with package-local SDK `1.30.0`; root SDK remains `2.3.0`. [Selected/latest Resolve requirements](https://github.com/samuelgursky/davinci-resolve-mcp/blob/f74eac02d4d8c2798595e62e019862f9e3aa8ff2/requirements.txt#L11-L15) still require SDK <2, and [selected SDK2’s FastMCP placeholder](https://github.com/modelcontextprotocol/python-sdk/blob/2118f14f8a19bc158d8a1cf90af58d85d187f849/src/mcp/server/fastmcp.py) raises ModuleNotFoundError. The isolation constraint is unchanged; no new build or native/authenticated runtime proof was produced.

- **Changed (2026-11-18):** the build runs `packages/davinci-resolve-mcp/check-sdk.py` against the selected source's `requirements.txt`: it fails when the `mcp` requirement rejects the bundled SDK (upstream moved to SDK 2, which would otherwise only fail at runtime: the package is a `runCommand` without a runtime-deps check) and when it accepts nixpkgs' SDK (check whether the bundled one can go); a requirements file without exactly one applicable `mcp` line (markers evaluated) also fails. Resolve MCP 5.3.4 still requires `mcp[cli]>=1.30,<2`; nixpkgs `1a08097f` ships mcp 2.3.0.

- **Where:** `packages/davinci-resolve-mcp/default.nix` (package-local SDK 1 recipe; `check-sdk.py` beside it).
- **Why:** Resolve MCP requires `mcp>=1.30,<2`, but the selected nixpkgs package is 2.3.0. SDK 2 removes the `mcp.server.fastmcp` interface used by the server. (When this was added for Resolve MCP 4.10.4, nixpkgs had 1.29.0.)
- **Upstream / selected pin:** [Resolve MCP 5.3.4 requirements](https://github.com/samuelgursky/davinci-resolve-mcp/blob/v5.3.4/requirements.txt); [SDK 1.30.0](https://github.com/modelcontextprotocol/python-sdk/releases/tag/v1.30.0). The local override selects that tagged SDK without changing other MCP clients' package sets.
- **Remove when:** selected nixpkgs provides an SDK accepted by Resolve MCP with `mcp.server.fastmcp` (`check-sdk.py` then fails the build as a prompt to check); remove the package-local SDK recipe and the check and use `python3.pkgs.mcp`.
- **Validate:** `ceres` and `nix build --no-link .#davinci-resolve-mcp`; import Resolve's native scripting module inside its FHS environment, reject unauthenticated HTTP requests, initialize an authenticated MCP session, list tools, and query the running Resolve version through Executor.
- **Exercised:** 2026-10-10: SDK checks (1212 passed), full Ceres and Vesta builds, Juno1 system evaluation, native scripting import, HTTP authentication and Host rejection, authenticated discovery of 37 tools, quiet journald logging, and a live Resolve Studio 21.1.0.17 version query through Executor passed.

#### `t3code-nightly-trusted-networks`

- **Review (2026-11-15):** `required`. Full Ceres, Pallas and Vesta select nightly `0.1.10-nightly.20261115.4736` ([7379f196](https://github.com/pingdotgg/t3code/blob/7379f1969b0f4b579327cf81299ef8cc3ddf8e9c/apps/server/src/peer/PeerLinks.ts#L155)). Its HTTP guard, [latest nightly .4749](https://github.com/pingdotgg/t3code/blob/295a0a7332aa1b0cc2f737dae71bd5e607a6ebb9/apps/server/src/peer/PeerLinks.ts#L155) and [live main 51cdf232](https://github.com/pingdotgg/t3code/blob/51cdf232652db8cdcea806f9a9e27d7460868579/apps/server/src/peer/PeerLinks.ts#L155) still allow only loopback/Tailscale, with no configured-overlay setting. The local patch remains limited to that guard, with exact hostname matching and CIDR membership; all three systems configure only the two Nebula CIDRs and exact `/etc/hosts` peer names, without suffixes or trailing dots. Retain the repack. No new build or authenticated runtime check was run; stored-link and redirect limitations remain.

- **Where:** `packages/t3code-nightly/trusted-networks.patch`, applied to the server bundle that `sea-unpack.py` extracts from the release SEA before `node --build-sea` (nixpkgs `nodejs-slim_26`) packs it again; `check-trusted-networks.sh` in the install check. `T3CODE_TRUSTED_NETWORKS` is set from the Nebula CIDRs and peer names in `modules/home/agents/t3code.nix`.
- **Why:** `peerOrigin` in [`apps/server/src/peer/PeerLinks.ts`](https://github.com/pingdotgg/t3code/blob/9a35ab0afeae64ac7c3bf92d674ead365cf55e10/apps/server/src/peer/PeerLinks.ts#L150-L178) refuses `http:` peer links unless the host is loopback or Tailscale (`*.ts.net`, `fd7a:115c:a1e0::/48`). Nebula encrypts the overlay the same way, so the hosts link over `http://<host>.nebula.internal:3773` without a TLS proxy. The patch adds the hosts listed in `T3CODE_TRUSTED_NETWORKS` (comma-separated CIDRs and exact host names; empty by default) to that check only, by shadowing `isTailnetHost` inside `peerOrigin`, so the hunk avoids bundler-renamed identifiers such as `fail$9`. `isTailnetHost` itself stays unchanged because it also classifies Tailscale interfaces. Names match exactly and without a trailing dot because the guard does not resolve them: only names that `common/nebula.nix` pins to overlay addresses in `/etc/hosts` are listed, never a DNS suffix (the apex `nebula.sgiath.dev` is public, and `ceres.nebula.sgiath.dev.` skips `/etc/hosts`). The setting governs link creation only; T3 does not recheck stored links, so removing an entry does not revoke a link. Upstream also sends MCP requests with fetch's default redirect following (descriptor and OAuth requests use `redirect: "manual"`); worth raising with the issue. Ingress from the LAN to overlay listeners is tracked in [the overlay-listener note](.agents/notes/proposed/bug-fix/2026-11-15-overlay-listeners-lan-ingress.md).
- **Upstream:** no issue filed yet; the guard is unchanged since [4005759a](https://github.com/pingdotgg/t3code/commit/4005759adf35c0355892ea1083ecd9426526a12c) (2026-10-27).
- **Selected pin:** nightly 0.1.10-nightly.20261113.4643 (9a35ab0a). The patch applies without fuzz to the bundles of .4564, .4616, .4643 and .4669.
- **Remove when:** upstream allows plain-http links to a configured overlay network; switch the module to its setting and drop the repack.
- **Validate:** `nix build --no-link .#t3code-nightly` (the install check runs `t3 environment link` against trusted and untrusted hosts); runtime: link two hosts over their `http://<host>.nebula.internal:3773` URLs and list projects on the linked one.
- **Exercised (2026-11-15):** the install check failed against the unpatched .4643 (`http://ceres.t3.invalid:9 ... is plain http`) and against an earlier suffix-matching revision (`sub.ceres.t3.invalid` accepted), and passes with this patch. Vesta, on the patched build, linked to Ceres over `http://ceres.nebula.sgiath.dev:3773` with `full-access`; an authenticated MCP `tools/list` and project listing through the link succeeded, and with the variable empty the same link was refused.

#### `t3code-nightly-arm64-sea-page-size`

- **Where:** `packages/t3code-nightly/default.nix` (`meta.platforms = [ "x86_64-linux" ]`), so aarch64 evaluation refuses the package. No host uses the nightly CLI on aarch64; `t3code-nightly-desktop` (AppImage, no repack) keeps aarch64.
- **Why:** the package repacks the release SEA with `node --build-sea`, whose Linux arm64 output fails on kernels with 16 or 64 KiB pages. Upstream's own ARM64 release injects the blob with postject instead (`scripts/lib/linux-arm64-sea.ts`, [pingdotgg/t3code#25825](https://github.com/pingdotgg/t3code/pull/25825)). The ARM tarballs also lack ffi-rs's musl build, which the install phase deletes, so a native build would fail there first.
- **Upstream:** [nodejs/node#67048](https://github.com/nodejs/node/issues/67048) open (checked 2026-11-18).
- **Selected pin:** nightly `0.1.11-nightly.20261118.4864`, repacked on `nodejs-slim_26` 26.13.1 (from `nixpkgs-master`).
- **Remove when:** the selected Node's `--build-sea` works on 16/64 KiB page arm64 kernels, or the repack injects with postject as upstream does; then add `aarch64-linux` back, make the musl cleanup tolerate the missing ffi-rs build, and build natively.
- **Validate:** native aarch64 build of `.#t3code-nightly` (its install check runs `t3 --version`) on a 64 KiB page kernel.

#### `katrain-kivy-cython-long`

- **Review (2026-11-15):** `required`. Selected Kivy remains [2.3.1/20d74dcd](https://github.com/kivy/kivy/tree/20d74dcd30f143abbd1aa94c76bafc5bd934d5bd) with Cython `3.3.0`; direct source inspection still finds both replaced constructs. Comparing Python-2 removal `dcd8fb2a` to the selected release is diverged (ahead 114, behind 22). New [Kivy 2.3.2](https://github.com/kivy/kivy/blob/ec09ee880c666e70de42501f36dbc43e349e3712/kivy/graphics/instructions.pyx#L896-L901) still retains the dict_keys branch and is not selected. The removal gate is unchanged and unmet.

- **Where:** `packages/katrain/default.nix` (Kivy `postPatch` replacing Python 2 `long` in `weakproxy.pyx`, `context_instructions.pyx`, `opengl.pyx`, and the PY2 `dict_keys` assignment in `instructions.pyx`).
- **Why:** Kivy 2.3.1 does not build with current Cython. Cython 3.2 dropped the `long` builtin. Cython 3.3 also type-checks the dead `if PY2:` branch of `RenderContext.apply` and fails with `instructions.pyx:899:41: Cannot assign type 'dict_keys object' to 'list object'`, so that branch now uses the same `list(self.state_stacks.keys())` as the Python 3 one.
- **Upstream:** fixed on Kivy HEAD 9bd35c59 ([weakproxy.pyx](https://github.com/kivy/kivy/blob/9bd35c595760fe6909e6889b9aefe659a57f9eae/kivy/weakproxy.pyx#L250)); the `instructions.pyx` branch went away in [kivy#8610](https://github.com/kivy/kivy/pull/8610) (dcd8fb2a), which removed all Python 2 compatibility code. Neither is in release 2.3.1, which is selected.
- **Selected pin:** root nixpkgs Cython 3.3.0 for the package-local Python 3.13 set.
- **Remove when:** the selected Kivy contains these fixes and satisfies KaTrain; remove the replacements before `--replace-fail` breaks.
- **Validate:** `ceres` and `nix build --no-link .#katrain`; runtime: KaTrain renders and analyzes a board.
- **Exercised (2026-10-20):** without the `instructions.pyx` replacement the full Ceres build failed in Kivy with the Cython 3.3 error above. With it Kivy and KaTrain build (35 KaTrain tests pass, the GPU test stays deselected), the full Ceres build passes, and headless imports of `kivy.graphics.instructions`, `kivy.core.audio` and `katrain.core.game` work. The UI wasn't started.

#### `katrain-chardet-major-version`

- **Review (2026-11-15):** `required`. Nothing material changed: full Ceres’s KaTrain `1.20.0` still depends on chardet `6.0.0.post1`, while [selected/latest KaTrain](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml#L23) requires <6. Keep the relaxation; non-UTF-8 SGF/NGF/GIB import remains unexercised.

- **Where:** `packages/katrain/default.nix` (`pythonRelaxDeps` for `chardet`).
- **Why:** KaTrain requires `chardet>=5.2.0,<6` ([pyproject L23](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/pyproject.toml#L23)); root nixpkgs ships 6.0.0.post1.
- **Remove when:** the selected KaTrain accepts the selected chardet (or a compatible chardet is used).
- **Validate:** `ceres`; runtime: import non-UTF-8 SGF/NGF/GIB files, names/comments decode.

#### `katrain-bundled-katago-appimage`

- **Review (2026-11-15):** `required`. Nothing material changed: [selected/latest KaTrain `f4981cf9`](https://github.com/sanderland/katrain/tree/f4981cf905cece90085ce4e3967415d0c16d525f/katrain/KataGo) still bundles a type-2 AppImage. The existing selected output’s engine requires libOpenCL.so.1 and libzip.so.4; selected libzip `1.11.4` supplies soname 5. Retain extraction and the bundled ABI library; OpenCL analysis and move proof remain missing.

- **Where:** `packages/katrain/default.nix` (extract bundled OpenCL KataGo AppImage, keep its `libzip.so.4`, drop Windows assets).
- **Why:** avoids FUSE/AppRun assumptions in the sandbox; nixpkgs libzip has another soname. Keeps upstream's engine rather than silently switching to nixpkgs KataGo.
- **Upstream:** [KaTrain KataGo dir](https://github.com/sanderland/katrain/tree/f4981cf905cece90085ce4e3967415d0c16d525f/katrain/KataGo); rationale is local, not re-reproduced.
- **Remove when:** the selected release ships a NixOS-compatible engine with OpenCL and ABI deps, or extraction becomes unnecessary.
- **Validate:** `ceres`; runtime: OpenCL engine analysis and a move on Ceres (`--help` is not proof).

#### `katrain-opencl-test-exclusion`

- **Review (2026-11-15):** `required`. Nothing material changed: [selected/latest KaTrain test](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/tests/test_ai.py#L16-L19) still requires KataGo/OpenCL and skips itself in upstream CI. The selected package excludes only test_ai_strategies. No hermetic replacement, package check-phase run or GPU runtime proof was established.

Also covers audit ID `package-katrain-opencl-test`.

- **Where:** `packages/katrain/default.nix` (disables only `test_ai_strategies`; temporary `HOME`).
- **Why:** the test constructs `KataGoEngine` and needs an OpenCL device; upstream itself skips it in CI ([test_ai.py](https://github.com/sanderland/katrain/blob/f4981cf905cece90085ce4e3967415d0c16d525f/tests/test_ai.py#L17)).
- **Remove when:** the test becomes hermetic/CPU-backed, or the sandbox gets a deterministic software OpenCL.
- **Validate:** `ceres` plus package check phase; runtime as `katrain-bundled-katago-appimage`.

#### `whiteboard-angle-runpath`

- **Review (2026-11-15):** `required`. Selected/latest Whiteboard advanced to [0.5.2/03d373ab](https://github.com/devdotfast/whiteboard/releases/tag/v0.5.2), but the exact selected DEB’s libGLESv2.so still has no RPATH/RUNPATH and contains libEGL.so.1/libGL.so.1 loader names. The existing selected package’s library includes libglvnd 1.7.0 on RUNPATH after the local adaptation. The source/artifact constraint is unchanged; no Wayland canvas runtime proof establishes removal.

- **Where:** `packages/whiteboard/default.nix` (runtime dlopen deps; libglvnd appended to all relevant RUNPATHs).
- **Why:** bundled ANGLE loads libEGL/libGL itself; `runtimeDependencies` only reaches executables.
- **Upstream:** selected/latest [v0.2.4](https://github.com/devdotfast/whiteboard/releases/tag/v0.2.4) (2026-10-10).
- **Remove when:** a selected package/native build resolves EGL/GL without the extra RUNPATH.
- **Validate:** `desktop`; runtime: `whiteboard-desktop` and CLI-launched desktop render a canvas on Wayland.

#### `whiteboard-cli-desktop-environment`

- **Review (2026-11-15):** `required`. Selected Whiteboard is now [0.5.2/03d373ab](https://github.com/devdotfast/whiteboard/blob/03d373ab0bf64ae3e3a5e4e1e592cb4fd173871d/packages/review/src/review-app-launcher.ts#L310-L347). Its exact DEB confirms the same launcher contract as source and live main: environment variables are cleared upstream, but Electron launches process.execPath and the fallback remains /usr/bin/review-desktop. Nothing material changed in the remaining wrapper requirement; retain shared git/xdg-utils PATH and desktop wiring pending cold/warm/direct-launch and external-link checks.

- **Where:** `packages/whiteboard/default.nix` (both wrappers add git/xdg-utils; desktop clears `ELECTRON_RUN_AS_NODE`/`VSCODE_*`; CLI sets `ELECTRON_RUN_AS_NODE`; desktop file `Exec` rewritten).
- **Why:** the CLI launches the desktop through `process.execPath`, bypassing the desktop wrapper.
- **Upstream:** selected/latest [Whiteboard v0.2.4](https://github.com/devdotfast/whiteboard/releases/tag/v0.2.4) (2026-10-10). No equivalent native-NixOS launcher contract or specific upstream fix was established.
- **Remove when:** the selected CLI routes launches through a supported wrapper keeping the environment on cold/warm launch.
- **Validate:** `desktop`; runtime: CLI-initiated and direct desktop launches from an environment containing the Electron/VSCode variables; git and external links work.

#### `nak-network-check-disable`

- **Review (2026-11-15):** `required`. Full Ceres exposes nak `0.22.3`/`a3b1237b`, also latest. Its [selected tests](https://github.com/fiatjaf/nak/blob/a3b1237bb5325a21a01c132fb53bb615789c4242/cli_test.go#L165-L180) still contact public nos.lol. The network constraint is unchanged; doCheck=false remains, and no passing offline-only sandbox selection was established. No tests contacted relays.

Also covers audit ID `package-nak-network-tests`.

- **Where:** `packages/nak/default.nix` (`doCheck = false`); package exposed, not installed (`modules/home/terminal/role.nix` entry commented).
- **Why:** some tests contact public Nostr relays (selected [v0.21.2 cli_test.go](https://github.com/fiatjaf/nak/blob/v0.21.2/cli_test.go#L166-L180) runs `nak req … nos.lol`); others are offline, so the blanket skip is broader than needed. Selected = latest v0.21.2 (2026-10-10).
- **Remove when:** upstream makes relay tests opt-in/hermetic, or packaging selects only offline tests that pass in the sandbox.
- **Validate:** package build with checks and network disabled (meaningful tests run) plus `ceres`/`vesta`/`juno1` boundary; runtime: `nak` help and offline encode/decode.

#### `cross-architecture-nixos-rebuild-no-reexec`

- **Review (2026-11-15):** `candidate`. Nothing material changed in the source-level finding: [selected root `d5cc6833`](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/services.py#L29-L80) catches an incompatible reexec and restarts the current local binary; live master retains it. It still constructs the target rebuild before fallback. Keep the flag pending Ceres/Juno1 builds and an authorized x86-to-aarch64 deployment without it.

- **Where:** `packages/update/default.nix` (`--no-reexec` for `update --juno<N>`).
- **Why:** with `--build-host`/`--target-host` on aarch64, re-exec would replace the local x86_64 `nixos-rebuild` with the target's aarch64 binary.
- **Upstream:** [nixos-rebuild-ng](https://github.com/NixOS/nixpkgs/tree/b4fd65b198c599cbe814fcb9f42d25d021595ec9/pkgs/by-name/ni/nixos-rebuild-ng); no upstream change identified.
- **Remove when:** the selected rebuild keeps a runnable local binary for x86→aarch64 deployment.
- **Validate:** `ceres`, `juno1`; runtime: an authorized `update --juno1`.

#### `burn-iso-hybrid-mbr-key-partition`

- **Review (2026-11-15):** `unknown`. The exact selected ISO output `/nix/store/83cw8025vpv96n38b6c0kzc9cxg187hh-nixos-minimal-26.11.20261113.d5cc683-x86_64-linux.iso` is absent, so geometry inspection remains blocked under the no-build boundary. [Selected root `d5cc6833` iso-image.nix](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/nixos/modules/installer/cd-dvd/iso-image.nix#L1023-L1029) still supports hybrid MBR/EFI construction, which is not geometry proof. Nothing changed in the verification outcome; retain the adaptation. No image build, device write, key export or boot occurred.

- **Where:** `packages/burn-iso/default.nix` (settle/unmount, append `SGIATH-KEYS` via `sfdisk` to the hybrid ISO's MBR).
- **Why:** hybrid GPT/MBR geometry overlaps and the kernel reads the MBR; gptfdisk is unsuitable. No upstream issue; local layout evidence only.
- **Upstream:** no external fix/issue is identified: this is a local hybrid-ISO layout adaptation, not a package bug. Recheck the generated image geometry when its pinned inputs change.
- **Remove/change when:** the generated ISO geometry supports another strategy, proven on disposable media.
- **Validate:** `iso`; runtime: loop device/VM or expendable USB with fake keys boots and exposes the key partition.

### Kernels

#### `dgx-spark-nvidia-kernel-cve-2026-98432`

- **Review (2026-11-15):** `required`. Resolved dgx-spark remains `c646a19a`; full Juno1 selects `7.0.14-nvidia`, NV-Kernels [ae07646a](https://github.com/NVIDIA/NV-Kernels/tree/ae07646a606b3f18707246b0762464452cb40cbe). Both selected destructors still use plain `kfree()` ([af_inet.c](https://github.com/NVIDIA/NV-Kernels/blob/ae07646a606b3f18707246b0762464452cb40cbe/net/ipv4/af_inet.c#L165), [tcp_ipv4.c](https://github.com/NVIDIA/NV-Kernels/blob/ae07646a606b3f18707246b0762464452cb40cbe/net/ipv4/tcp_ipv4.c#L1232)), and derivation inspection confirms the local backport. [Live DGX main c215c456](https://github.com/graham33/nixos-dgx-spark/blob/c215c456a3b0654fb5dc3dd0b5d6b0cc47fc3b30/kernel-configs/nvidia-kernel-source.nix) still selects it. NVIDIA’s [7.0-next 18f0eb33](https://github.com/NVIDIA/NV-Kernels/tree/18f0eb33acddde0398e7b76354ad9840e3192174) now has both RCU frees, while bos-7.0-next `e01bfd69` does not; neither changes the selected-source gate. Retain the backport. No kernel build, deployment, reboot or remediation proof was produced.

- **Where:** `modules/nixos/hardware/dgx-spark.nix` (`boot.kernelPatches`), `modules/nixos/hardware/cve-2026-98432-ipv4-opt-rcu.patch` (the upstream commit, unmodified).
- **Why:** CVE-2026-98432 is a use-after-free. `inet_sock_destruct()` and `tcp_v4_reqsk_destructor()` free IPv4 options with plain `kfree()` while the SYNACK paths read them under `rcu_read_lock()` only. The patch changes both to `kfree_rcu(..., rcu)`. It goes through `boot.kernelPatches` because the kernel is built inside the upstream module; NixOS appends the patch in the `.override` of `boot.kernelPackages`.
- **Upstream:** [torvalds/linux e3f33b0a](https://github.com/torvalds/linux/commit/e3f33b0a1d89d738e2b913dab519226eaf76e15b), committed 2026-10-05. NV-Kernels `24.04_linux-nvidia-7.0-next` (58b5de53) and `24.04_linux-nvidia-bos-7.0-next` (e01bfd69) still use plain `kfree()` in both destructors, and [graham33/nixos-dgx-spark](https://github.com/graham33/nixos-dgx-spark) main is still the selected c646a19a (checked 2026-10-30).
- **Selected pin:** `dgx-spark` c646a19a selects NV-Kernels ae07646a (`7.0.14-nvidia`, tag `Ubuntu-nvidia-7.0-7.0.0-1019.19_24.04.2`), with plain `kfree()` at [af_inet.c#L165](https://github.com/NVIDIA/NV-Kernels/blob/ae07646a606b3f18707246b0762464452cb40cbe/net/ipv4/af_inet.c#L165) and [tcp_ipv4.c#L1232](https://github.com/NVIDIA/NV-Kernels/blob/ae07646a606b3f18707246b0762464452cb40cbe/net/ipv4/tcp_ipv4.c#L1232).
- **Remove when:** the NV-Kernels source selected by `inputs.dgx-spark` has `kfree_rcu(..., rcu)` in both destructors. The patch then stops applying and fails the kernel build, which is the prompt to check. Remove the `boot.kernelPatches` entry and the patch file together.
- **Validate:** `juno1`, including the native build. `nix derivation show` on `.#nixosConfigurations.juno1.config.boot.kernelPackages.kernel.drvPath` lists the patch in `patches`, and patching runs without fuzz. Runtime: after `update --juno1` and a reboot, `/run/booted-system/kernel` and `/run/current-system/kernel` resolve to the same rebuilt kernel, and the host boots with Nebula, RoCE and the GPU working. A switch without a reboot leaves the old kernel running.
- **Exercised (2026-10-30):** static only. The patches of the evaluated `linux-7.0.14-nvidia` derivation were applied with `--fuzz=0` to the pinned `af_inet.c` and `tcp_ipv4.c`: the unpatched derivation (s5jj8l7a) failed the destructor check and the patched one (rp8zlrpx) passed. The Juno1 toplevel evaluates, its derivation closure selects the patched kernel, the NVIDIA module derivation depends on it, and the upstream module's `overrideAttrs` reference scrubbing is unchanged. The kernel was not built or booted and the bug was not reproduced; Juno1 must be treated as vulnerable until this is deployed and rebooted.

#### `sctp-module-block`

- **Where:** `modules/nixos/common/security.nix` (ungated: `boot.blacklistedKernelModules = [ "sctp" ]` and `install sctp .../false` in `boot.extraModprobeConfig`), so it applies to every host including Hygiea.
- **Why:** the kernel SCTP send path has a use-after-free/double free (introduced in 4.15) that Xint chained with nginx2root to get root from an nginx worker, including from a container. Details are withheld until a kernel fix exists. Every host has `CONFIG_IP_SCTP=m`, and an unprivileged `socket(..., IPPROTO_SCTP)` autoloads it; the blacklist stops alias autoloading and the `install` line refuses an explicit `modprobe`. Nothing on these hosts uses kernel SCTP (WebRTC data channels run SCTP in userspace).
- **Upstream:** no kernel patch or CVE published as of 2026-11-18 ([Xint section 6](https://xint.io/blog/nginx2root-remote-code-execution)).
- **Selected pin:** Vesta 6.18.63 (module present, not loaded on 2026-11-18).
- **Remove when:** every selected kernel contains the SCTP fix, or keep it permanently since SCTP is unused. Neither unloads an already loaded module; a host with `sctp` in `/sys/module` needs a reboot.
- **Validate:** `all`; each host's `environment.etc."modprobe.d/nixos.conf".text` contains both lines. Runtime: `sudo modprobe sctp` fails and `/sys/module/sctp` is absent.

#### `pallas-alc298-speaker-init`

- **Where:** `systems/x86_64-linux/pallas/audio.nix` (udev rules starting `pallas-speaker-init.service`, which replays the vendor verb sequence through `hda-verb`, the same run after resume, runtime PM off for the codec).
- **Why:** the Blade 14 (2023) speaker amplifier behind the ALC298 codec (10ec:0298, subsystem 1a58:2020) stays silent until it receives a vendor coefficient sequence ([yadu-tv/rb14-2023-audio-fix](https://github.com/yadu-tv/rb14-2023-audio-fix) `e3d9b205`). Linux has no quirk for this SSID.
- **Upstream:** no kernel patch known. Pallas's Linux 7.3.4 `sound/hda/codecs/realtek/alc269.c` and mainline master (2026-11-18) list only Razer SSIDs 0x2023 and 0x300e.
- **Remove when:** the selected Pallas kernel has a quirk for 1a58:2020 and the speakers play without the service. Recheck the microphone priority rule then: it compensates for a jack microphone that the codec reports after the sequence.
- **Validate:** `pallas`; runtime: speakers play after boot and after resume; dictation uses the internal microphone.

### Security exceptions

Records from the security lifecycle audit. Bundled runtimes are invisible to nixpkgs `knownVulnerabilities`, so these deadlines are checked here. No `permittedInsecurePackages`, `allowInsecure`, `knownVulnerabilities` or `NIXPKGS_ALLOW_INSECURE` exists in the repository (2026-10-10).

#### `whiteboard-bundled-electron`

- **Review (2026-11-15):** `watch`. Full Ceres selects Whiteboard `0.5.2` ([03d373ab](https://github.com/devdotfast/whiteboard/tree/03d373ab0bf64ae3e3a5e4e1e592cb4fd173871d)). Its [package metadata](https://github.com/devdotfast/whiteboard/blob/03d373ab0bf64ae3e3a5e4e1e592cb4fd173871d/apps/review-desktop/code-oss/package.json#L177) and [checksums](https://github.com/devdotfast/whiteboard/blob/03d373ab0bf64ae3e3a5e4e1e592cb4fd173871d/apps/review-desktop/code-oss/build/checksums/electron.txt#L28) select Electron `43.8.6`; a static scan of the already-built selected binary also finds `Electron/43.8.6`. Electron 43 EOL is **2027-01-05** ([schedule](https://releases.electronjs.org/schedule.json)), 51 days away, outside the 30-day warning window. Retain the exception while Electron remains bundled. No build or desktop runtime check was run.

Also covers audit ID `package-whiteboard-bundled-electron`.

- **Where:** `packages/whiteboard/default.nix` (binary DEB with bundled Electron; current runtime major unverified).
- **Historical status (2026-10-10):** `watch` - Electron 43 EOL **2027-01-05** ([schedule](https://releases.electronjs.org/schedule.json)). Selected = latest upstream [v0.2.4](https://github.com/devdotfast/whiteboard/releases/tag/v0.2.4) (5b00f0e6) pins 43.7.9 ([electron checksums](https://github.com/devdotfast/whiteboard/blob/v0.2.4/apps/review-desktop/code-oss/build/checksums/electron.txt)); the packaged `share/whiteboard/whiteboard` of the selected `whiteboard-0.2.4` reports `Electron/43.7.9` (checked 2026-10-10). The earlier Electron 42 deadline (2026-10-20) no longer applies. On each manual review, warn before the date; after it, set `expired` and report.
- **Remove when:** the package no longer bundles its own Electron. Until then, move the deadline to the packaged major's EOL on each update (verify both source metadata and packaged runtime).
- **Validate:** `desktop`; runtime: desktop launch, CLI-to-desktop launch, one review/canvas flow.

## Deliberate choices (not upstream workarounds)

Not part of the manual upstream review. Revisit only when the named trigger
happens; do not remove them because upstream changed. Group names are stable.

| Group | Audit IDs | Where | Why it is not a workaround / revisit trigger |
| --- | --- | --- | --- |
| `channel-selection` | `master-channel-node26-selection`, `master-channel-factorio-experimental-selection`, `tuios-no-upstream-overlay-adapter` | `overlays/sgiath/default.nix` | Freshness preference (both currently equal root versions) and package-only input adapter. Revisit on freshness-policy change. |
| `executor-nebula-integrations` | `executor-private-network-access` | `modules/nixos/services/executor.nix`, `modules/home/agents/davinci-resolve-mcp.nix` | The personal self-hosted Executor may call authenticated MCP services on Nebula. `EXECUTOR_ALLOW_LOCAL_NETWORK=true` permits private endpoints; Resolve MCP binds only its Nebula address and requires a runtime bearer token. Revisit if Executor gains a narrower per-integration address allowlist. |
| `release-pins` | `ordinary-root-release-pins`, `standard-input-follows-and-overlays`, `flake-binary-cache-configuration`, `comfyui-upstream-release-pin` | `flake.nix`, `scripts/update-inputs.sh` | Ordinary tagged/immutable input refs advanced by the release updater, per-input `nixpkgs` follows, module wiring, upstream overlays, and substituter/key preferences. Hyprland's nixpkgs not following root is tracked in `desktop-hyprland-mesa-abi`. Trust/cache changes are separate scope. |
| `bird-product` | `bird-native-linux-chromium-cookie-source`, `bird-standard-pnpm-recipe`, `hermes-bird-vesta-command-adapter` | `vendor/bird/src/lib/cookies.ts`, `vendor/bird/src/lib/chromium-cookies.ts`, `packages/bird/default.nix`, `modules/nixos/services/hermes-bird-vesta.sh` | Required read-only open-Chromium cookie reading (v11 keyring unsupported), normal pnpm recipe, digest command adapter. Credential/security changes need the security model. |
| `comfyui-product` | `comfyui-cache-registration`, `comfyui-json-repair`, `comfyui-prompt-enhancer-node`, `comfyui-rocm-attention-policy`, `comfyui-bundled-nodes-opt-out`, `comfyui-qwen-service-state`, `comfyui-qwen-workflow-seeding`, `comfyui-qwen-model-downloads` | `flake.nix` nixConfig, `overlays/comfyui/default.nix`, `modules/nixos/services/comfyui.nix`, `systems/x86_64-linux/ceres/qwen-image.nix`, `systems/x86_64-linux/ceres/qwen-image/` | Cache opt-in, enhancer dependency/node pin, ROCm attention policy, node surface, user-owned state, edit-preserving workflow seeding, verified model downloader. `json-repair` migrates with `comfyui-service-overlay-selection`. |
| `package-recipes` | `local-product-packaging`, `katrain-package-integration-details`, `whiteboard-legacy-alias-removal`, `delta-authenticated-archive-packaging`, `relay-tester-manual-git-hash-refresh`, `quickshell-qtmultimedia-extension`, `quickshell-multimedia-and-qml-tooling` | `packages/`, `modules/home/desktop/quickshell.nix` | Ordinary reproducible packaging, binary relocation, QtMultimedia for video wallpaper. |
| `updater-and-maintenance` | `dnd5etools-split-image-release-policy`, `local-maintenance-and-installer-commands`, `development-shell-and-input-updater-policy`, `nebula-certificate-mobile-helpers` | `packages/dnd5etools/`, `packages/update/`, `packages/clear-cache/`, `packages/fix-images/`, `packages/live-install/`, `packages/burn-iso/`, `scripts/`, `shells/default/` | Local tools and update policy (dnd5etools images advanced manually by decision). |
| `security-policy` | `whiteboard-user-namespace-sandbox`, `grok-sandbox-off`, `installer-exported-keys-and-mobile-config`, `factorio-default-fetch-flow`, `factorio-headless-runtime-settings`, `matrix-livekit-runtime-turn-settings`, `normal-service-restart-and-auth-integrations` | `packages/whiteboard/default.nix`, `modules/home/agents/base.nix`, `packages/burn-iso/default.nix`, `scripts/nebula-mobile.sh`, `modules/nixos/gaming/role.nix`, `modules/nixos/services/factorio.nix`, `modules/nixos/services/matrix.nix`, agent/service modules | Intentional security-sensitive decisions: inert setuid helper removed (user-namespace sandbox, no `--no-sandbox`), explicit `GROK_SANDBOX=off`, exported installer keys, approved Factorio token handling, runtime credential serialization, service restart/auth boundaries. Change only by owner/security decision; never auto-remove. |
| `session-lifecycle` | `desktop-once-per-session-startup`, `desktop-launcher-independent-app-cgroups`, `herdr-managed-desktop-environment`, `docker-delayed-workstation-start`, `qml-local-reactivity-patterns`, `quickshell-icon-lookup-cost` | `modules/home/desktop/role.nix`, `modules/home/programs/chat.nix`, `modules/home/programs/email.nix`, `modules/home/agents/herdr-server.nix`, `modules/home/desktop/quickshell/`, `modules/nixos/services/docker.nix` | Required once-per-session startup, app cgroup isolation, Herdr daemon ownership and graphical environment, boot policy, local QML patterns, launcher icon omission (owned by the proposed icon-lookup note). |
| `module-wiring` | `stylix-global-overlay-ownership`, `worktrunk-module-precedence`, `noctalia-v5-module-and-visual-contract`, `herdr-theme-parser-integration`, `theme-base16-dark-metadata` | `modules/nixos/desktop/stylix.nix`, `modules/home/desktop/stylix.nix`, `modules/home/terminal/worktrunk.nix`, `modules/home/terminal/herdr.nix`, `modules/home/desktop/noctalia.nix`, `themes/`, `flake.nix` module lists | Chosen module providers (HM worktrunk module enabled with upstream's `homeModules.default` supplying the flake package default; HM Noctalia instead of the flake module), overlay ownership, theme data contract. Change only with the provider design. |
| `host-product-choices` | `host-hardware-and-build-resource-choices`, `networking-and-live-iso-forces`, `gaming-steam-lutris-prism-overrides`, `foundry-release-channel-override`, `hermes-feature-groups-and-user`, `gtk-chromium-wayland-preferences`, `other-package-selection-and-styling-preferences` | `modules/nixos/hardware/`, `systems/x86_64-linux/`, `modules/nixos/common/`, `modules/nixos/gaming/role.nix`, `modules/home/gaming/role.nix`, `modules/nixos/services/foundryvtt.nix`, `modules/nixos/services/hermes-agent.nix`, desktop modules | Hardware, network, game, licensing and appearance choices. |

### Stale comments (cleanup only, no workaround)

Fix together with the next change touching the file; behavior must not change.

- `flake.nix` keeps a commented-out `nixpkgs-stable` input; no stable-channel workaround is active. Do not delete transitive lock nodes by name (`retired-stable-channel-comment`).
- `homes/x86_64-linux/sgiath@ceres/default.nix` says login default stays Noctalia; the evaluated default is `sgiath` (`noctalia-login-comment-stale`).
- `modules/home/terminal/herdr.nix` comment names Yoru; the parser reads `themes/sgiath.yaml` (`herdr-yoru-comment-stale`).
- `packages/katrain/default.nix` claims Kivy Python 3.14 support was merged; kivy#9225 is open.
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
| `ollama-rocm-gfx-override-dormant` | 2026-11-12 | Removed together with `modules/nixos/services/ollama.nix`, which no host enabled; Ceres runs llama.cpp on Vulkan (`services/llama-cpp.nix`) instead, with no ROCm target override. The RX 6950 XT is native gfx1030, so the 10.3.0 override was a no-op. |
| `home-manager-gpg-ssh-unit-cycle` | 2026-10-10 | Override removed: pinned Home Manager dfadbe51 contains e9cbe698 and no longer orders `set-SSH_AUTH_SOCK` against socket providers (2026-10-01 read-only comparison gave identical fields). Owner validates `all` and a real login without the ordering cycle. |
| `amd-radv-nofibril` | 2026-10-10 | Flag removed: selected Mesa 26.1.5 `radv_perftest_options` has no `nofibril`, so it was a no-op. Owner compares a game/shader-compilation workload on Ceres after removal. |
| `davinci-resolve-21-1-republished-hash` | 2026-10-10 | Overlay removed: root nixpkgs contains NixOS/nixpkgs#562336 (748f45f3) and its corrected hashes; upstream `davinci-resolve-studio` is used. The only consumer stays commented out in `homes/x86_64-linux/sgiath@ceres/default.nix`. Owner validates the package and licensed runtime on enablement. |
| `sops-nix-build-go126-fork` | 2026-10-10 | Input moved to `github:Mic92/sops-nix`, locked at the same 16954c1c (identical narHash; Mic92 master contains it). Owner validates `all` and sops activation after removal. |
| `pihole-ftl-gcc16-unused-counter` | 2026-10-28 | Overlay and patch removed: root nixpkgs selects FTL 6.8, whose `src/config/validator.c` `sanitize_dns_hosts` (lines 1016-1024) already lacks the counter ([pi-hole/FTL#2939](https://github.com/pi-hole/FTL/pull/2939), merged 2026-07-07), so the backport failed to apply (`Reversed (or previously applied) patch detected!`). The unchanged package build reproduced that failure; after removal the upstream cached package and full Vesta toplevel build pass. Runtime checks remain for deployment: `pihole-ftl` healthy, local `dns.hosts` names and public DNS answer. |
| `desktop-hyprland-elf-wrapper` | 2026-10-29 | Override removed: selected Hyprland v0.57.0 (0aa6745f) `nix/default.nix` takes `makeBinaryWrapper` directly (lines 7, 167) and wraps `bin/Hyprland` with `wrapProgram` adding binutils, hyprland-guiutils, pciutils and pkgconf to PATH (lines 255-263), so the stale `makeWrapper` override failed evaluation (`unexpected argument 'makeWrapper'`). After removal `programs.hyprland.package` is the unmodified upstream derivation and the full Ceres toplevel builds; `ensure-wrapper-integrity` accepts the ELF launcher and validates all capabilities. Runtime launch through greetd's `start-hyprland` with screen sharing remains unchecked pending activation. |
| `preview-share-picker-region-coordinates` | 2026-11-05 | Retired with the 0.3.1 pin (`preview-share-picker-hyprland-057-ipc`): v0.3.1 `src/config.rs` defaults `region.command` to `slurp -f '%o@%X,%Y,%W,%H'` (output-relative, PR #26). The setting stays, unchanged, for its absolute `slurp` path. Runtime region selection on a monitor away from the layout origin remains to be checked after activation. |
| `t3code-nightly-sea-patchelf` | 2026-11-15 | The patchelf 0.15.5 pin is gone: `t3` is now repacked on nixpkgs Node (`t3code-nightly-trusted-networks`), already links its libraries and is no longer patchelf'd; `autoPatchelf` runs on the native modules beside it with the default patchelf. |
| `openclaw-desktop-deep-link-wrapper`, `openclaw-desktop-remote-ssh-limitation`, `openclaw-desktop-asset-aware-updater`, `openclaw-tauri-binary-layout` | 2026-11-10 | Removed together with `packages/openclaw-desktop` (last selected 2026.11.1) and the OpenClaw gateway/node modules; OpenClaw is no longer used. |
| `zenpower-kbuild-module-install` | 2026-11-18 | Overlay removed: root `1a08097f` `pkgs/os-specific/linux/zenpower/default.nix` takes `kernelModuleMakeFlags` and installs through `modules_install` itself. Ceres, Pallas and Vesta toplevels and the Ceres modules tree build; booted `sensors` remains to be checked after activation. |
| `xanmod-tools-128bit-types-duplicate` | 2026-11-18 | Filter removed and `boot.kernelPackages = pkgs.linuxPackages_xanmod_latest` restored: root `1a08097f` lists only `bridge_stp_helper` and `request_key_helper` for XanMod main. The Ceres kernel derivation is identical before and after (`ypb429b8…-linux-xanmod-7.3.4.drv`). |
| `chatgpt-tpm2-tss-build-inputs` | 2026-11-18 | Override removed: llm-agents `aca6bfb2` `packages/chatgpt/unwrapped.nix` lists `openssl` and `tpm2-tss`. Ceres `llm-agents.chatgpt` and the Ceres/Pallas toplevels build; Remote Control pairing remains unchecked. |
| `cinny-desktop-gst-plugins` | 2026-11-18 | Override removed: root `1a08097f` gives Cinny gst-plugins base, good, bad and ugly. Ceres `cinny-desktop` and the Ceres/Pallas toplevels build; audio playback remains to be checked after activation. |
| `lk-jwt-service-aws-lc-inputs` | 2026-11-18 | Override removed: root `1a08097f` lists `aws-lc` and `pkg-config`. Vesta `lk-jwt-service` and toplevel build; the Element Call token check remains for deployment. |
| `nostr-rs-relay-system-jemalloc` | 2026-11-18 | Override removed: root `1a08097f` lists `rust-jemalloc-sys`. Vesta `nostr-rs-relay` and toplevel build; relay startup remains for deployment. |
| `presenterm-oniguruma-inputs` | 2026-11-18 | Override removed: root `1a08097f` lists `pkg-config` and `oniguruma`. Ceres `presenterm` (tests and version check) and the Ceres/Pallas/Vesta toplevels build. |
| `primp-system-library-inputs` | 2026-11-18 | `pythonPackagesExtensions` entry removed: root `1a08097f` lists `pkg-config`, `aws-lc` and `zstd-c`. Ceres `python3Packages.primp` (pytest and import check) and the toplevels build. |
| `llm-agents-hermes-nemo-relay-aws-lc`, `hermes-agent-exact-pin-relax` | 2026-11-18 | `llm-agents.hermes-agent` and `hermes-desktop` overrides removed: llm-agents `aca6bfb2` gives nemo-relay `pkg-config`, `aws-lc` and `zstd` (`packages/hermes-agent/package.nix` lines 83-88) and relaxes `markdown` and `prompt_toolkit` (lines 671-677). Ceres `llm-agents.hermes-agent` and `hermes-desktop` build; the interactive CLI remains unchecked. |
| `preview-share-picker-hyprland-057-ipc` | 2026-11-18 | Override removed: root `1a08097f` selects `hyprland-preview-share-picker` 0.3.1 with the same source hash. The dark wrapper and absolute `region.command` stay. Ceres/Pallas toplevels build; a ScreenCast request with Outputs/Windows thumbnails remains to be checked after activation. |
| `hex-serial-tests` | 2026-11-21 | Override removed: hex `96b4f365` (`nix/package.nix` lines 257-261) now sets `dontUseCargoParallelTests = true` itself. The unmodified `hex-3.4.0` (3020 passed, 0 failed) and both Ceres and Pallas toplevels build cleanly. |
| `hyprland-glaze-release-freeze` | 1544288d | The v0.56.1 pin and updater marker were already removed when `flake.nix` moved to Hyprland v0.57.x (currently `v0.57.2`/`11cbc6c5`, whose CMake accepts glaze without a version bound). Desktop toplevels build cleanly and Ceres runs Hyprland v0.57.2. |
| `tmux-sessionizer-session-target` | ea43ce72 | Removed together with `modules/home/terminal/tmux.nix`; tmux and `tmux-sessionizer` are no longer installed or configured on any host. |
| `portal-qt-theme-isolation` | 2026-11-24 | `UnsetEnvironment` (`QT_QPA_PLATFORMTHEME`, `QT_STYLE_OVERRIDE`) removed from `modules/nixos/desktop/wayland.nix`: selected `xdg-desktop-portal-hyprland` (`85450448`) uses `hyprtoolkit` with zero Qt libraries in its transitive closure and no references to either variable, and `share-picker.nix` uses GTK `hyprland-preview-share-picker`. Ceres and Pallas toplevels build cleanly; live screen-share check remains for deployment. |

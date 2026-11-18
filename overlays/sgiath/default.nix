{ inputs, ... }:
final: prev:
let
  inherit (prev) lib;

  pkgs-master = import inputs.nixpkgs-master {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };

  pkgs-ksa = import inputs.nixpkgs-ksa {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  nodejs-slim_26 = pkgs-master.nodejs-slim_26;

  ksa = pkgs-ksa.ksa;
  factorio-space-age-experimental = pkgs-master.factorio-space-age-experimental;

  # nginx2root (CVE-2026-123007 and others) is fixed in 1.30.7; take it from
  # master until the selected nixpkgs has it. See
  # UPSTREAM-WORKAROUNDS.md#nginx-2026-11-security-release.
  nginxStable =
    if lib.versionOlder prev.nginxStable.version "1.30.7" then
      pkgs-master.nginxStable
    else
      prev.nginxStable;

  # otelcol-contrib 0.155.0 pins cockroachdb/swiss b0f6560f, whose runtime
  # hooks exclude Go 1.27 (undefined hashFn), so build it with Go 1.26. Scoped
  # to 0.155.0: a new release builds with the default Go again; see
  # UPSTREAM-WORKAROUNDS.md#otelcol-contrib-swiss-go127.
  opentelemetry-collector-contrib =
    if prev.opentelemetry-collector-contrib.version == "0.155.0" then
      (prev.opentelemetry-collector-releases.override {
        buildGoModule = final.buildGo126Module;
      }).otelcol-contrib
    else
      prev.opentelemetry-collector-contrib;

  # Hermes' nix/pm-packages.nix applies patchelf#672 (written for 0.19) to
  # whatever patchelf nixpkgs selects, and it does not apply to 0.15.2, which
  # predates the bug the patch fixes. Below 0.18 the PM artifacts use the
  # selected patchelf unpatched; see
  # UPSTREAM-WORKAROUNDS.md#hermes-agent-node-patchelf.
  hermes-agent =
    if lib.versionOlder final.patchelf.version "0.18" then
      prev.hermes-agent.override (old: {
        pmPackages = lib.mapAttrs (
          _: pmPackage:
          pmPackage.overrideAttrs (pmOld: {
            nativeBuildInputs = map (
              input: if lib.getName input == "patchelf" then final.patchelf else input
            ) pmOld.nativeBuildInputs;
          })
        ) old.pmPackages;
      })
    else
      prev.hermes-agent;

  # llm-agents codex builds openssl-sys through AWS-LC's compat openssl.pc,
  # which nixpkgs AWS-LC 5.12.0 installs only with its OpenSSL shim, and
  # openssl-sys's bindgen rejects AWS-LC's default symbol prefix. Applies while
  # the AWS-LC codex receives lacks the shim or has a prefix. llm-agents' own
  # scope passes its codex to t3code, so t3code and t3code-desktop take this
  # one explicitly; see UPSTREAM-WORKAROUNDS.md#llm-agents-codex-aws-lc-openssl-shim.
  llm-agents =
    let
      awsLc = lib.findFirst (input: lib.getName input == "aws-lc") null prev.llm-agents.codex.buildInputs;
      needsShim =
        awsLc != null
        && !(
          lib.elem (lib.cmakeBool "ENABLE_DIST_PKG_OPENSSL_SHIM" true) awsLc.cmakeFlags
          && !lib.any (lib.hasPrefix "-DBORINGSSL_PREFIX:") awsLc.cmakeFlags
        );
    in
    prev.llm-agents
    // {
      codex =
        if needsShim then
          prev.llm-agents.codex.override {
            aws-lc = final.aws-lc.override {
              withOpenSSLShim = true;
              symbolPrefix = null;
            };
          }
        else
          prev.llm-agents.codex;
      t3code =
        if needsShim then
          prev.llm-agents.t3code.override { inherit (final.llm-agents) codex; }
        else
          prev.llm-agents.t3code;
      t3code-desktop =
        if needsShim then
          prev.llm-agents.t3code-desktop.override { inherit (final.llm-agents) t3code; }
        else
          prev.llm-agents.t3code-desktop;
    };
}

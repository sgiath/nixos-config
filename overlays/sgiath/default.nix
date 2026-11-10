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

  # FIXME: otelcol-contrib 0.155.0 pins cockroachdb/swiss b0f6560f, whose
  # runtime hooks exclude Go 1.27, so the default Go 1.27 build fails with
  # undefined hashFn. Build only contrib with Go 1.26 (source generation and
  # version unchanged). Drop once the selected contrib builds with default Go;
  # see UPSTREAM-WORKAROUNDS.md#otelcol-contrib-swiss-go127.
  opentelemetry-collector-contrib =
    (prev.opentelemetry-collector-releases.override {
      buildGoModule = final.buildGo126Module;
    }).otelcol-contrib;

  # FIXME: Cinny's WebKit aborts in createAudioSink because nixpkgs only
  # gives it gst-plugins-base (no autoaudiosink, fakevideosink or WebVTT).
  # Drop once the selected cinny-desktop lists gst-plugins-good and -bad
  # itself; see UPSTREAM-WORKAROUNDS.md#cinny-desktop-gst-plugins.
  cinny-desktop = prev.cinny-desktop.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [
      final.gst_all_1.gst-plugins-good
      final.gst_all_1.gst-plugins-bad
    ];
  });

  # FIXME: the Rust cargo setup hook exports AWS_LC_SYS_USE_SYSTEM=1, but
  # lk-jwt-service 0.9.0 gives aws-lc-sys no aws-lc or pkg-config, so its build
  # script panics. Backports nixpkgs master's inputs for the same source. Drop
  # once the selected lk-jwt-service lists aws-lc and pkg-config itself; see
  # UPSTREAM-WORKAROUNDS.md#lk-jwt-service-aws-lc-inputs.
  lk-jwt-service = prev.lk-jwt-service.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ final.aws-lc ];
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.pkg-config ];
  });

  # FIXME: the cargo setup hook exports JEMALLOC_OVERRIDE (a missing
  # sentinel) unless a system jemalloc sets it, and nostr-rs-relay 0.10.0 lists
  # none, so tikv-jemalloc-sys fails. rust-jemalloc-sys keeps the crate's
  # _rjem_ prefix. Drop once the selected nostr-rs-relay lists it itself; see
  # UPSTREAM-WORKAROUNDS.md#nostr-rs-relay-system-jemalloc.
  nostr-rs-relay = prev.nostr-rs-relay.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ final.rust-jemalloc-sys ];
  });

  # FIXME: the cargo setup hook forces RUSTONIG_SYSTEM_LIBONIG, but presenterm
  # 0.16.1 gives onig_sys neither oniguruma nor pkg-config. Backports nixpkgs
  # master's inputs for the same source; see
  # UPSTREAM-WORKAROUNDS.md#presenterm-oniguruma-inputs.
  presenterm = prev.presenterm.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ final.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [ final.oniguruma ];
  });

  # FIXME: the cargo setup hook forces ZSTD_SYS_USE_PKG_CONFIG and
  # AWS_LC_SYS_USE_SYSTEM, but primp 2.0.1 lists neither library nor
  # pkg-config. Backports nixpkgs master's inputs for the same source into
  # every Python set; see UPSTREAM-WORKAROUNDS.md#primp-system-library-inputs.
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_: pyprev: {
      primp = pyprev.primp.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ final.pkg-config ];
        buildInputs = old.buildInputs ++ [
          final.aws-lc
          final.zstd
        ];
      });
    })
  ];

  # FIXME: Hermes' pm-packages.nix appends patchelf#672 (written against
  # 0.19.2) to whatever patchelf nixpkgs selects, so the PM artifacts fail on
  # the selected 0.15.2, where the patch does not apply. Releases before 0.18
  # predate the header-rewrite regression the patch fixes, so use the selected
  # patchelf unpatched for every PM artifact; from 0.18 on keep Hermes' own.
  # See UPSTREAM-WORKAROUNDS.md#hermes-agent-node-patchelf.
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

  llm-agents = prev.llm-agents // {
    # FIXME: llm-agents codex builds openssl-sys against AWS-LC's compat
    # openssl.pc, which nixpkgs AWS-LC 5.12.0 only installs with its OpenSSL
    # shim, and openssl-sys's bindgen-cli path rejects its default symbol
    # prefix. Drop once the selected llm-agents codex or nixpkgs AWS-LC
    # provides it; see UPSTREAM-WORKAROUNDS.md#llm-agents-codex-aws-lc-openssl-shim.
    codex = prev.llm-agents.codex.override {
      aws-lc = final.aws-lc.override {
        withOpenSSLShim = true;
        symbolPrefix = null;
      };
    };
    # Replacing codex in this attrset does not reach llm-agents' own scope,
    # so t3code (and the nightly wrappers using its providerPackages) would
    # still carry the unfixed codex. Drop with the codex override above.
    t3code = prev.llm-agents.t3code.override {
      inherit (final.llm-agents) codex;
    };
    t3code-desktop = prev.llm-agents.t3code-desktop.override {
      inherit (final.llm-agents) t3code;
    };

    # FIXME: remote-control-device-key.node links tpm2-tss and libcrypto, but
    # llm-agents only finds them through RUNPATHs of systemd < 262 libraries.
    # Drop once the selected llm-agents chatgpt-unwrapped lists both itself.
    chatgpt = prev.llm-agents.chatgpt.override {
      chatgpt-unwrapped = prev.llm-agents.chatgpt.unwrapped.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [
          final.openssl
          final.tpm2-tss
        ];
      });
    };

    # FIXME: Hermes builds its private nemo-relay 0.11.1 (aws-lc-sys 0.45,
    # zstd-sys) without aws-lc, zstd or pkg-config, so the cargo setup hook's
    # AWS_LC_SYS_USE_SYSTEM and ZSTD_SYS_USE_PKG_CONFIG fail. Only the
    # recipe's python3 can reach that let binding, so wrap its
    # buildPythonPackage for that one package; Hermes' dependencies, Python
    # env and passthru all get the fixed build. Drop once the selected
    # llm-agents lists them; see
    # UPSTREAM-WORKAROUNDS.md#llm-agents-hermes-nemo-relay-aws-lc.
    # FIXME: Hermes pins prompt_toolkit and Markdown with ==, and our nixpkgs
    # already has newer patch releases than llm-agents' own. Drop once the
    # selected llm-agents hermes-agent relaxes both itself.
    hermes-agent =
      (prev.llm-agents.hermes-agent.override (old: {
        python3 = old.python3 // {
          pkgs = old.python3.pkgs // {
            buildPythonPackage =
              args:
              let
                pkg = old.python3.pkgs.buildPythonPackage args;
              in
              if pkg.pname or null == "nemo-relay" then
                pkg.overridePythonAttrs (pkgOld: {
                  nativeBuildInputs = pkgOld.nativeBuildInputs ++ [ final.pkg-config ];
                  buildInputs = (pkgOld.buildInputs or [ ]) ++ [
                    final.aws-lc
                    final.zstd
                  ];
                })
              else
                pkg;
          };
        };
      })).overridePythonAttrs
        (old: {
          pythonRelaxDeps = old.pythonRelaxDeps ++ [
            "prompt_toolkit"
            "markdown"
          ];
        });
    hermes-desktop = prev.llm-agents.hermes-desktop.override {
      inherit (final.llm-agents) hermes-agent;
    };

    # FIXME: Remote LiteLLM (through CLIProxyAPI) ends a chat-completions
    # stream with a usage chunk whose choice has no finish reason, which fx
    # rejects after printing the answer. Drop once fx accepts that trailer.
    fx = prev.llm-agents.fx.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./fx-usage-trailer.patch ];
    });
  };

  # FIXME: zenpower copies its module by hand, so Kbuild never writes the
  # zenpower.ko.cer that aggregateModules now merges into modules.cer. Drop once
  # pinned nixpkgs installs zenpower through modules_install
  # (https://github.com/NixOS/nixpkgs/issues/575192).
  kernelPackagesExtensions = prev.kernelPackagesExtensions ++ [
    (kfinal: kprev: {
      zenpower = kprev.zenpower.overrideAttrs (old: {
        makeFlags =
          kfinal.kernelModuleMakeFlags
          ++ old.makeFlags
          ++ [
            "INSTALL_MOD_PATH=${placeholder "out"}"
            "INSTALL_MOD_DIR=kernel/drivers/hwmon/zenpower"
            "INSTALL_MOD_STRIP=1"
            "DEPMOD=true"
          ];
        installTargets = [ "modules_install" ];
        installFlags = [
          "-C"
          "${kfinal.kernel.dev}/lib/modules/${kfinal.kernel.modDirVersion}/build"
          "M=$(PWD)"
        ];
        installPhase = null;
      });
    })
  ];
}

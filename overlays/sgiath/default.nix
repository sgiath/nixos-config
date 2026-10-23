{ inputs, ... }:
final: prev:
let
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

  # FIXME: FTL 6.7.1 fails under GCC 16 -Werror (unused counter in
  # sanitize_dns_hosts). Drop once pinned nixpkgs ships FTL with
  # https://github.com/pi-hole/FTL/pull/2939.
  pihole-ftl = prev.pihole-ftl.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./pihole-ftl-unused-counter.patch ];
  });

  # FIXME: patchelf 0.18+ (interpreter, then RPATH) leaves Node 26's .dynamic
  # in a RW LOAD that the next read-only LOAD overlaps, so ld.so segfaults and
  # the TUI build dies in `npm config`. Drop once nixpkgs patchelf leaves the
  # pinned node runnable; see UPSTREAM-WORKAROUNDS.md#hermes-agent-node-patchelf.
  hermes-agent = prev.hermes-agent.override (old: {
    pmPackages = old.pmPackages // {
      node = old.pmPackages.node.overrideAttrs (nodeOld: {
        nativeBuildInputs = [
          (final.patchelf.overrideAttrs (
            patchelfFinal: _: {
              version = "0.15.5";
              src = final.fetchurl {
                url = "https://github.com/NixOS/patchelf/releases/download/${patchelfFinal.version}/patchelf-${patchelfFinal.version}.tar.bz2";
                hash = "sha256-E02LFkLBmE6FYjvAm/pYKayzIs9sgNzGDVcdzcrQng0=";
              };
            }
          ))
        ]
        ++ nodeOld.nativeBuildInputs;
      });
    };
  });

  llm-agents = prev.llm-agents // {
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

    # FIXME: Hermes pins prompt_toolkit and Markdown with ==, and our nixpkgs
    # already has newer patch releases than llm-agents' own. Drop once the
    # selected llm-agents hermes-agent relaxes both itself.
    hermes-agent = prev.llm-agents.hermes-agent.overridePythonAttrs (old: {
      pythonRelaxDeps = old.pythonRelaxDeps ++ [
        "prompt_toolkit"
        "markdown"
      ];
    });
    hermes-desktop = prev.llm-agents.hermes-desktop.override {
      inherit (final.llm-agents) hermes-agent;
    };
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

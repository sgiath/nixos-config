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

  # v2026.8.13 ships registration_lifecycle.py but omits it from
  # [tool.setuptools].py-modules, so the sealed uv2nix venv cannot import it
  # and both gateway + dashboard crash on plugin load. Upstream fixed this
  # in 89d3e43; drop this once a release includes that commit.
  registrationLifecycle = prev.python312.pkgs.toPythonModule (
    prev.runCommand "hermes-registration-lifecycle" { } ''
      mkdir -p $out/${prev.python312.sitePackages}
      cp ${./registration_lifecycle.py} $out/${prev.python312.sitePackages}/registration_lifecycle.py
    ''
  );
in
{
  ksa = pkgs-ksa.ksa;
  factorio-space-age-experimental = pkgs-master.factorio-space-age-experimental;

  hermes-agent = prev.hermes-agent.override (old: {
    extraPythonPackages = (old.extraPythonPackages or [ ]) ++ [ registrationLifecycle ];
  });

  llm-agents = prev.llm-agents // {
    openclaw = prev.llm-agents.openclaw.overrideAttrs (old: {
      # Numtide builds the gateway and UI in separate processes. Share the
      # reproducible timestamp so both generate the same package build identity.
      preBuild = (old.preBuild or "") + ''
        export OPENCLAW_BUILD_TIMESTAMP="$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%dT%H:%M:%S.000Z)"
      '';
    });
    hermes-one = prev.llm-agents.hermes-one.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./hermes-one-compat.patch ];
    });
  };
}

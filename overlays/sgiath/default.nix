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

  # Blackmagic re-published the 21.1 archives without bumping the version, so
  # nixpkgs' fixed-output hash no longer matches. Drop this once
  # https://github.com/NixOS/nixpkgs/pull/562336 lands in nixos-unstable.
  davinci-resolve-dir = prev.applyPatches {
    name = "davinci-resolve-pkg";
    src = "${inputs.nixpkgs}/pkgs/by-name/da/davinci-resolve";
    patches = [
      (prev.fetchurl {
        url = "https://github.com/NixOS/nixpkgs/pull/562336.patch";
        hash = "sha256-udJQb7sjGBq2tEfmMwD9hQsf8VB1U/QMZvU79iLyxNI=";
      })
    ];
    patchFlags = [ "-p5" ];
  };
in
{
  ksa = pkgs-ksa.ksa;
  factorio-space-age-experimental = pkgs-master.factorio-space-age-experimental;

  hermes-agent = prev.hermes-agent.override (old: {
    extraPythonPackages = (old.extraPythonPackages or [ ]) ++ [ registrationLifecycle ];
  });

  davinci-resolve-studio = prev.callPackage "${davinci-resolve-dir}/package.nix" {
    studioVariant = true;
  };
}

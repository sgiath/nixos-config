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
  nodejs-slim_26 = pkgs-master.nodejs-slim_26;

  ksa = pkgs-ksa.ksa;
  factorio-space-age-experimental = pkgs-master.factorio-space-age-experimental;

  davinci-resolve-studio = prev.callPackage "${davinci-resolve-dir}/package.nix" {
    studioVariant = true;
  };

  # FIXME: FTL 6.7.1 fails under GCC 16 -Werror (unused counter in
  # sanitize_dns_hosts). Drop once pinned nixpkgs ships FTL with
  # https://github.com/pi-hole/FTL/pull/2939.
  pihole-ftl = prev.pihole-ftl.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./pihole-ftl-unused-counter.patch ];
  });
}

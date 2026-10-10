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
}

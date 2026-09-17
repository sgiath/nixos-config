{
  pkgs,
  mkShell,
  ...
}:
mkShell {
  packages = with pkgs; [
    nil
    nixd
    nixfmt
    nodejs
    shfmt
    prettier
    pnpm

    # encrypted runtime secrets
    sops
    age
    ssh-to-age
    nebula # nebula-cert for scripts/nebula-sign.sh

    # isolated security checks
    bubblewrap
    (python3.withPackages (ps: [ ps.pyyaml ]))

    # package updater
    curl
    dpkg
    gh
    gnupg
    jq
    nix-prefetch
    perl
    prefetch-npm-deps
  ];
}

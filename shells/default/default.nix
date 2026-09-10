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

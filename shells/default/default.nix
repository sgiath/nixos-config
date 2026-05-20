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
    nixfmt-tree
    nodejs
    shfmt
    prettier

    # package updater
    curl
    jq
    nix-prefetch
    nix-prefetch-github
    prefetch-npm-deps
  ];
}

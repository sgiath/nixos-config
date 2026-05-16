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

    # package updater
    curl
    jq
    nix-prefetch
    nix-prefetch-github
    prefetch-npm-deps
  ];
}

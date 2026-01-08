{
  pkgs,
  mkShell,
  ...
}:

mkShell {
  packages = with pkgs; [
    nixd
    nixfmt

    nodejs
    node2nix

    shfmt
  ];
}

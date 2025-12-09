{
  pkgs,
  mkShell,
  ...
}:

mkShell {
  packages = with pkgs; [
    nixd
    nixfmt-rfc-style

    nodejs
    node2nix

    shfmt
  ];
}

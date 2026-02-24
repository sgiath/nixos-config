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

    shfmt
  ];
}

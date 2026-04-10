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
  ];
}

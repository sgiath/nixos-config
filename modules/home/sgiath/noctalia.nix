{
  config,
  pkgs,
  inputs,
  ...
}:
{
  programs.noctalia-shell = {
    enable = true;
    # settings = { };
  };
}

{ config, pkgs, ...}:

{
  home.packages = [ pkgs.nixd ];
  programs.NvChad = {
    enable = true;
    defaultEditor = true;
    otherConfigs = ./NvChad;
  };
}

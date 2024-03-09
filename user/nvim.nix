{ config, pkgs, NvChad, ...}:

{
  imports = [
    NvChad.homeManagerModules.default
  ];

  home.packages = [ pkgs.nixd ];
  programs.NvChad = {
    enable = true;
    defaultEditor = true;
    otherConfigs = ./NvChad;
  };
}

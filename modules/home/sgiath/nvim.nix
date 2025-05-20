{config, lib, pkgs, ...}:
{
    programs.nixvim = {
      enable = true;
      extraPlugins = [ pkgs.vimPlugins.yorumi ];
      colorscheme = "yorumi";
    };
}
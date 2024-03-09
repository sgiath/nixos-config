{ config, pkgs, ...}:

{
  # nixd LSP
  home.packages = [ pkgs.nixd ];

  # package
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # config files
  xdg = {
    enable = true;
    configFile.nvim.source = config.lib.file.mkOutOfStoreSymlink ./nvim;
  };

  # ripgrep
  programs.ripgrep.enable = true;
}

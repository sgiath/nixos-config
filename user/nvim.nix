{ config, pkgs, ... }:

{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # nixd LSP
  home.packages = with pkgs; [ neovim nixd lua-language-server stylua gcc gnumake ];
  # ripgrep
  programs.ripgrep.enable = true;

  # config files
  xdg = {
    enable = true;
    configFile.nvim = {
      source = config.lib.file.mkOutOfStoreSymlink ./nvim;
      recursive = true;
    };
  };
}

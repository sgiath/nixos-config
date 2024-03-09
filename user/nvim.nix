{ config, pkgs, userSettings, ...}:

{
  # nixd LSP
  home.packages = with pkgs; [ neovim nixd gcc gnumake];

  # config files
  xdg = {
    enable = true;
    configFile.nvim = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/user/nvim";
      recursive = true;
    };
  };

  # ripgrep
  programs.ripgrep.enable = true;
}

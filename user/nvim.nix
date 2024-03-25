{ config, pkgs, ... }:

{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # nixd LSP
  home.packages = with pkgs; [
    # base deps
    gcc
    gnumake
    neovim

    # Nix
    nixd
    nixfmt

    # Lua
    lua-language-server
    stylua

    # Markdown formatter
    # https://github.com/executablebooks/mdformat
    python311Packages.mdformat
    python311Packages.mdformat-gfm
    python311Packages.mdformat-frontmatter
    python311Packages.mdformat-footnote

    # shell
    shfmt

    # general formatter
    codespell
  ];

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

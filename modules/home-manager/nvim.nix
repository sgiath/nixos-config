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
    nixfmt-rfc-style

    # Lua
    lua-language-server
    stylua

    # Markdown formatter
    # https://github.com/executablebooks/mdformat
    python312Packages.mdformat
    python312Packages.mdformat-gfm
    python312Packages.mdformat-frontmatter
    python312Packages.mdformat-footnote

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

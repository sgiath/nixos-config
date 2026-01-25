{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.programs.nvim = {
    enable = lib.mkEnableOption "Neovim";
  };

  config = lib.mkIf config.programs.nvim.enable {
    # nixd LSP
    home.packages = with pkgs; [
      # base deps
      neovim

      # Zig
      zig
      zls

      # Nix
      nixd
      nixfmt

      # Lua
      lua-language-server
      stylua

      # Markdown formatter
      # https://github.com/executablebooks/mdformat
      # python314Packages.mdformat
      # python314Packages.mdformat-gfm
      # python314Packages.mdformat-frontmatter
      # python314Packages.mdformat-footnote

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
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home/sgiath/nvim";
        recursive = true;
      };
    };
  };
}

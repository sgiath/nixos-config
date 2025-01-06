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
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    programs.nvf = {
      enable = true;
      settings.vim = {
        autocomplete = {
          nvim-cmp.enable = true;
        };

        autopairs.enable = true;

        comments = {
          comment-nvim.enable = true;
        };

        dashboard = {
          startify.enable = true;
        };

        debugger = {
          nvim-dap.enable = true;
        };

        filetree = {
          nvimTree = {
            enable = true;
          };
        };

        git = {
          enable = true;
          gitsigns.enable = true;
          vim-fugitive.enable = true;
        };

        languages = {
          enableDAP = true;
          enableFormat = true;
          enableLSP = true;
          enableTreesitter = true;

          bash.enable = true;
          css.enable = true;
          elixir.enable = true;
          html.enable = true;
          markdown.enable = true;
          nix.enable = true;
          python.enable = true;
          sql.enable = true;
          tailwind.enable = true;
          terraform.enable = true;
          zig.enable = true;
        };

        lazy = {
          enable = true;
        };

        lsp = {
          enable = true;
        };

        notes = {
          obsidian.enable = true;
          todo-comments.enable = true;
        };

        notify = {
          nvim-notify.enable = true;
        };

        options = {
          shiftwidth = 2;
          tabstop = 2;
        };

        preventJunkFiles = true;
        syntaxHighlighting = true;
        useSystemClipboard = true;

        snippets = {
          luasnip.enable = true;
        };

        spellcheck = {
          enable = true;
        };

        statusline = {
          lualine.enable = true;
        };

        telescope = {
          enable = true;
        };

        theme = {
          enable = true;
          name = "dracula";
        };

        treesitter = {
          enable = true;
          autotagHtml = true;
        };

        ui = {
          colorizer.enable = true;
          noice.enable = true;
          smartcolumn.enable = true;
        };

        undoFile = {
          enable = true;
        };

        utility = {
          images = {
            image-nvim.enable = true;
          };

          preview = {
            markdownPreview.enable = true;
          };
        };
      };
    };

    # nixd LSP
    # home.packages = with pkgs; [
    #   # base deps
    #   neovim
    #
    #   # Zig
    #   zig
    #   zls
    #
    #   # Nix
    #   nixd
    #   nixfmt-rfc-style
    #
    #   # Lua
    #   lua-language-server
    #   stylua
    #
    #   # Markdown formatter
    #   # https://github.com/executablebooks/mdformat
    #   python312Packages.mdformat
    #   python312Packages.mdformat-gfm
    #   python312Packages.mdformat-frontmatter
    #   python312Packages.mdformat-footnote
    #
    #   # shell
    #   shfmt
    #
    #   # general formatter
    #   codespell
    # ];

    # ripgrep
    programs.ripgrep.enable = true;

    # config files
    # xdg = {
    #   enable = true;
    #   configFile.nvim = {
    #     source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/modules/home/sgiath/nvim";
    #     recursive = true;
    #   };
    # };
  };
}

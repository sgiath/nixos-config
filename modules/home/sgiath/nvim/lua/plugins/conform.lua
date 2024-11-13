return {
	{
		"stevearc/conform.nvim",
		opts = {
			lsp_fallback = true,

			formatters_by_ft = {
				lua = { "stylua" },

				sh = { "shfmt" },
        md = { "mdformat" },
        nix = { "nixfmt" },
        -- nix = { "alejandra" },

        elixir = { "mix" },

        ["*"] = { "codespell" },
        ["_"] = { "trim_whitespace" },
			},
		},
	},
}

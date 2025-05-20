local options = {
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
}

return options

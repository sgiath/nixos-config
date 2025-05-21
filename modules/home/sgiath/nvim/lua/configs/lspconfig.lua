require("nvchad.configs.lspconfig").defaults()

local servers = {
	lua_ls = {},
	nixd = {
		nixpkgs = {
			expr = "import <nixpkgs> { }",
		},
		formatting = {
			command = { "alejandra" },
		},
		options = {
			nixos = {
				expr = '(builtins.getFlake "/home/sgiath/nixos").nixosConfigurations.ceres.options',
			},
			home_manager = {
				expr = '(builtins.getFlake "/home/sgiath/nixos").homeConfigurations.sgiath.options',
			},
		},
	},
}

for name, opts in pairs(servers) do
	vim.lsp.enable(name)
	vim.lsp.config(name, opts)
end

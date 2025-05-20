require("nvchad.configs.lspconfig").defaults()

local configs = require("nvchad.configs.lspconfig")

local on_attach = configs.on_attach
local on_init = configs.on_init
local capabilities = configs.capabilities

local lspconfig = require("lspconfig")
local servers = { "lua_ls", "zls" }

lspconfig.nixd.setup({
	cmd = { "nixd" },
	on_init = on_init,
	on_attach = on_attach,
	capabilities = capabilities,
	settings = {
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
	},
})

for _, lsp in ipairs(servers) do
	lspconfig[lsp].setup({
		on_init = on_init,
		on_attach = on_attach,
		capabilities = capabilities,
	})
end

-- vim.notify = require("noice").notify
-- vim.lsp.handlers["textDocument/hover"] = require("noice").hover
-- vim.lsp.handlers["textDocument/signatureHelp"] = require("noice").signature

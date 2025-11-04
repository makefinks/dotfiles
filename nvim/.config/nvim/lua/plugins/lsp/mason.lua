---@type LazySpec
return {
	-- use mason-tool-installer for automatically installing Mason packages
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		opts = {
			ensure_installed = {

				-- LSP servers
				"lua-language-server",
				"basedpyright",
				"bash-language-server",
				"json-lsp",
				"yaml-language-server",
				"html-lsp",
				"css-lsp",
				"marksman",
				"dockerfile-language-server",
				"docker-compose-language-service",
				"taplo",
				"typescript-language-server",
				"angular-language-server",

				-- Formatters & linters used by conform
				"stylua",
				"biome",
				"eslint_d",
				"ruff",
				"shfmt",
				"shellcheck",
				"hadolint",

				-- Debuggers & tools
				"debugpy",
				"tree-sitter-cli",
			},
		},
	},
}

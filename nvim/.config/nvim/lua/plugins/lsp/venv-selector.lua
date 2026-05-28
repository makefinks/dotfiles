---@type LazySpec
return {
	"linux-cultist/venv-selector.nvim",
	ft = "python",
	dependencies = {
		"neovim/nvim-lspconfig",
		"folke/snacks.nvim",
	},
	keys = {
		{ "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Select Python venv" },
	},
	opts = {
		options = {
			picker = "snacks",
		},
		search = {
			workspace = {
				command = "fd '/bin/python$' . --full-path --hidden --exclude .git --color never",
			},
		},
	},
}

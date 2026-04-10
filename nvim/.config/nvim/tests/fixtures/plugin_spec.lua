return {
	"folke/snacks.nvim",
	priority = 1000,
	keys = {
		{
			"<leader>fs",
			function()
				Snacks.picker.grep()
			end,
			desc = "Grep",
		},
		{
			"<leader>lF",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "LSP Functions",
		},
	},
	opts = {
		picker = { enabled = true },
		notifier = { enabled = true },
	},
}

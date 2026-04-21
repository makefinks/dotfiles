return {
	"dnlhc/glance.nvim",
	cmd = "Glance",
	keys = {
		{ "gR", "<CMD>Glance references<CR>", desc = "LSP references (Glance)" },
		{ "gT", "<CMD>Glance type_definitions<CR>", desc = "LSP type definitions (Glance)" },
	},
	opts = {
		height = 25,
		border = {
			enable = true,
		},
	},
}

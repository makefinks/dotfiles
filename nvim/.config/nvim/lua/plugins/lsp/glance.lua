return {
	"dnlhc/glance.nvim",
	cmd = "Glance",
	vim.keymap.set("n", "gR", "<CMD>Glance references<CR>"),
	vim.keymap.set("n", "gT", "<CMD>Glance type_definitions<CR>"),
	opts = {
		border = {
			enable = true,
		},
	},
}

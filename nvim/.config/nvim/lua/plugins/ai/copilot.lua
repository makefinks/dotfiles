return {
	"zbirenbaum/copilot.lua",
	enabled = require("toggles").enabled("copilot"),
	lazy = true,
	event = "InsertEnter", -- Load only on typing
	opts = {
		filetypes = {
			markdown = true,
		},
		suggestion = {
			enabled = true,
			auto_trigger = true,
			keymap = {
				accept = "<C-l>",
				next = "<C-j>",
			},
		},
	},
}

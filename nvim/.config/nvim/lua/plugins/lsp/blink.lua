return {
	"saghen/blink.cmp",
	event = "VeryLazy",
	opts = {
		enabled = function()
			return vim.bo.filetype ~= "dap-repl"
		end,
		keymap = {
			preset = "default",
			["<C-l>"] = { "show", "show_documentation", "hide_documentation" }
		},
		signature = {
			enabled = true,
			trigger = {
				show_on_keyword = false,
				show_on_trigger_character = true,
				show_on_insert = true,
			},
			window = {
				border = "rounded",
				show_documentation = true,
			},
		},
	},
}

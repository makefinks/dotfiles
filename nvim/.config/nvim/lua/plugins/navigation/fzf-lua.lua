return {
	"ibhagwan/fzf-lua",
	cmd = "FzfLua",
	opts = {
		blines = {
			prompt = "↯ ",
			winopts = {
				height = 0.80,
				width = 0.80,
				row = 0.55,
				col = 0.50,
				backdrop = 100,
				title_pos = "left",
				preview = {
					layout = "horizontal",
					horizontal = "right:50%",
					title_pos = "left",
				},
			},
			fzf_opts = {
				["--layout"] = "reverse",
				["--info"] = "hidden",
				["--pointer"] = " ",
				["--scrollbar"] = "",
			},
		},
		previewers = {
			builtin = {
				snacks_image = false, -- disable snacks image preview
			},
		},
	},
	keys = {
		{
			"<leader>fj",
			"<cmd>FzfLua blines<cr>",
			desc = "Fuzzy find in buffer",
		},
	},
}

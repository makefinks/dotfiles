return {
	"mrjones2014/smart-splits.nvim",
	event = "WinEnter",
	opts = {
		-- Determines how much Cltr + Arrows key resizes
		default_amount = 20,
	},
	keys = {
		{
			"<C-S-Up>",
			function()
				require("smart-splits").resize_up()
			end,
			mode = { "n", "i", "t" },
			desc = "Resize split up",
		},
		{
			"<C-S-Down>",
			function()
				require("smart-splits").resize_down()
			end,
			mode = { "n", "i", "t" },
			desc = "Resize split down",
		},
		{
			"<C-S-Left>",
			function()
				require("smart-splits").resize_left()
			end,
			mode = { "n", "i", "t" },
			desc = "Resize split left",
		},
		{
			"<C-S-Right>",
			function()
				require("smart-splits").resize_right()
			end,
			mode = { "n", "i", "t" },
			desc = "Resize split right",
		},
		{
			"<M-S-Up>",
			function()
				require("smart-splits").resize_up()
			end,
			mode = { "n", "i", "t" },
			desc = "Resize split up",
		},
		{
			"<M-S-Down>",
			function()
				require("smart-splits").resize_down()
			end,
			mode = { "n", "i", "t" },
			desc = "Resize split down",
		},
		{
			"<M-S-Left>",
			function()
				require("smart-splits").resize_left()
			end,
			mode = { "n", "i", "t" },
			desc = "Resize split left",
		},
		{
			"<M-S-Right>",
			function()
				require("smart-splits").resize_right()
			end,
			mode = { "n", "i", "t" },
			desc = "Resize split right",
		},
	},
}

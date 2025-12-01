return {
	"tanvirtin/vgit.nvim",
	dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" },
	event = "VimEnter",
	keys = {
		-- Diff views
		{
			"<leader>gd",
			function()
				require("vgit").buffer_diff_preview()
			end,
			desc = "Buffer diff (unified)",
		},
		{
			"<leader>gD",
			function()
				require("vgit").project_diff_preview()
			end,
			desc = "Project diff",
		},

		-- Conflict resolution
		{
			"<leader>gco",
			function()
				require("vgit").buffer_conflict_accept_current()
			end,
			desc = "Accept current (ours)",
		},
		{
			"<leader>gci",
			function()
				require("vgit").buffer_conflict_accept_incoming()
			end,
			desc = "Accept incoming (theirs)",
		},
		{
			"<leader>gcb",
			function()
				require("vgit").buffer_conflict_accept_both()
			end,
			desc = "Accept both",
		},
	},
	config = function()
		require("vgit").setup({
			settings = {
				live_blame = { enabled = false },
				live_gutter = { enabled = false },
				scene = {
					diff_preference = "unified",
				},
			},
		})
	end,
}

return {
	"tanvirtin/vgit.nvim",
	dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" },
	lazy = true,
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
		{
			"<leader>gb",
			function()
				local branch = vim.fn.input("Branch: ", "main")
				if branch ~= "" then
					require("vgit").buffer_diff_preview({ branch = branch })
				end
			end,
			desc = "Buffer diff against branch",
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
				hls = {
					GitSignsAdd = {
						fg = "#5a9dc7",
						bg = nil,
					},
					GitSignsDelete = {
						fg = "#cc0000",
						bg = nil,
					},
					GitSignsAddLn = {
						fg = "#5a9dc7",
						bg = "#2a3f4d",
					},
					GitSignsDeleteLn = {
						fg = "#cc0000",
						bg = "#4d2a2a",
					},
					GitWordAdd = {
						fg = nil,
						bg = "#2a3f4d",
					},
					GitWordDelete = {
						fg = nil,
						bg = "#4d2a2a",
					},
				},
			},
		})
	end,
}

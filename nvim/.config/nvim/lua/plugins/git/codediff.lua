---@type LazySpec
return {
	"esmuellert/codediff.nvim",
	cmd = { "CodeDiff" },
	keys = {
		{
			"<leader>gd",
			function()
				require("user.codediff").current_file_diff()
			end,
			desc = "Current file diff",
		},
		{
			"<leader>gD",
			function()
				require("user.codediff").project_diff()
			end,
			desc = "Project diff",
		},
		{
			"<leader>gU",
			function()
				require("user.codediff").project_diff({ hide_untracked = false })
			end,
			desc = "Project diff (with untracked)",
		},
		{
			"<leader>gq",
			function()
				require("user.codediff").close_view()
			end,
			desc = "Close codediff",
		},
		{
			"<leader>g<CR>",
			function()
				require("user.codediff").resume_last_session()
			end,
			desc = "Resume codediff",
		},
		{
			"<leader>gF",
			function()
				require("user.codediff").file_in_branch()
			end,
			desc = "File in another branch",
		},
		{
			"<leader>gP",
			function()
				require("user.codediff").open_pr_diff_against_branch()
			end,
			desc = "PR diff against branch",
		},
	},
	config = function()
		require("user.codediff").setup()
	end,
}

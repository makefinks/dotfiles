return {
	"NeogitOrg/neogit",
	cmd = { "Neogit" },
	dependencies = {
		"nvim-lua/plenary.nvim",
		"sindrets/diffview.nvim",
		"nvim-telescope/telescope.nvim",
	},
	keys = {
		{
			"<leader>gn",
			function()
				require("neogit").open({ kind = "tab" })
			end,
			desc = "[G]it [N]eogit status",
		},
	},
	config = function()
		local neogit = require("neogit")
		neogit.setup({})

		local function set_neogit_diff_colors()
			vim.api.nvim_set_hl(0, "NeogitDiffAddHighlight", { fg = "#5a9dc7", bg = "#2a3f4d" })
			vim.api.nvim_set_hl(0, "NeogitDiffDeleteHighlight", { fg = "#cc0000", bg = "#4d2a2a" })
		end

		set_neogit_diff_colors()

		-- persist after color scheme change
		vim.api.nvim_create_autocmd("ColorScheme", {
			callback = set_neogit_diff_colors,
		})
	end,
}

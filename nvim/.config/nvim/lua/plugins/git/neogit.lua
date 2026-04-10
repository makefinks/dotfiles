return {
	"NeogitOrg/neogit",
	cmd = { "Neogit" },
	dependencies = {
		"nvim-lua/plenary.nvim",
		"esmuellert/codediff.nvim",
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
		neogit.setup({
			-- Route Neogit diff opens through codediff so the same explorer flow and keymaps apply everywhere.
			integrations = {
				codediff = true,
			},
			-- Use codediff as the diff viewer instead of the old diffview setup.
			diff_viewer = "codediff",
		})

		local function set_neogit_diff_colors()
			vim.api.nvim_set_hl(0, "NeogitDiffAddHighlight", { fg = "#5a9dc7", bg = "#2a3f4d" })
			vim.api.nvim_set_hl(0, "NeogitDiffDeleteHighlight", { fg = "#cc0000", bg = "#4d2a2a" })
			vim.api.nvim_set_hl(0, "NeogitDiffAddInline", { fg = "#7fb6d8", bg = "#365261", bold = true })
			vim.api.nvim_set_hl(0, "NeogitDiffDeleteInline", { fg = "#f08a8a", bg = "#633838", bold = true })
		end

		set_neogit_diff_colors()

		-- persist after color scheme change
		vim.api.nvim_create_autocmd("ColorScheme", {
			callback = set_neogit_diff_colors,
		})
	end,
}

return {
	"folke/snacks.nvim",
	priority = 1000,
	keys = {
		-- Remap snacks git branch picker to <leader>gB (<leader>gb is reserved for other git mappings)
		{ "<Leader>gb", false },
		{ "<leader>fw", false },
		{ "<Leader>gB", function() Snacks.picker.git_branches() end, desc = "Git branches" },
		{
			"<leader>lF",
			function()
				Snacks.picker.lsp_symbols({
					filter = {
						default = { "Function", "Method" },
					},
				})
			end,
			desc = "LSP Functions",
		},
	},
	-- Lazy‑load on command or event if you like, e.g.:
	-- cmd = "Snacks", event = "VeryLazy",
	opts = function()
		local quotes = require("utils.quotes")
		local quote_formatter = require("utils.quote_formatter")

		local logo = [[
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣤⠀⠀⢀⣶⢇⣿⠇⠀⠀⠀⢀⣾⣿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣠⣤⣬⣽⣶⠆⠀⠀⠀⢀⣾⣿⠃⠀⣤⣶⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⡟⠛⠛⠋⠉⠉⠀⠀⠀⢀⣾⣿⣃⣀⣀⣼⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣤⣤⣤⣶⣶⣶⠀⠀⠀⠾⠿⠿⠛⠛⠛⠋⠛⠛⠀⠀⠀⠀⣀⣀⣀⣀⣤⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⠀⠀⠀⠀⠀⠀⣤⣤⣶⣶⣶⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠛⠉⠉⠉⠉⢀⣀⣀⣀⠀⢀⣤⣤⣤⣦⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⢀⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣠⣤⣄⣀⠀⠀⣤⣤⣤⣴⠄⠀⠀⠀⠀⠀⣴⣿⣿⡿⢁⣿⣿⣿⡏⠀⢸⣿⣿⣿⣿⠀⠀⠀⠀⣰⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⣼⣿⣿⣿⠇⠀⣤⣶⣶⣶⣶⣶⣿⣿⣿⡿⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⢸⣿⣿⣿⠀⠀⠀⠀⢀⣼⣿⣿⡟⠀⣼⣿⣿⣿⠀⢀⣿⣿⣿⣿⣿⠀⠀⢀⣼⣿⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⣿⡇⠀⠀⢰⣿⣿⣿⡟⠀⢰⣿⣿⣿⠿⠿⠿⠿⠛⠛⠃⠀⣾⣿⣿⡟⠋⠉⠉⠉⣻⣿⣿⡏⠀⢸⣿⣿⣿⠀⠀⠀⢀⣾⣿⣿⠏⠀⢠⣿⣿⣿⠇⠀⣼⣿⣿⣿⣿⣿⡇⣠⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⣿⢿⣿⣿⣿⣷⠀⢀⣿⣿⣿⣿⠁⢀⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⡿⠀⠀⠀⠀⢠⣿⣿⣿⠁⠀⢸⣿⣿⡿⠀⠀⢠⣾⣿⣿⠋⠀⠀⣾⣿⣿⡟⠀⢰⣿⣿⣿⢹⣿⣿⣷⣿⣿⡿⢡⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⡟⠀⣿⣿⣿⣿⡄⣸⣿⣿⣿⠇⠀⣼⣿⣿⣿⣶⣶⣶⣿⣿⠃⠀⢠⣿⣿⣿⠃⠀⠀⠀⠀⣼⣿⣿⠇⠀⠀⢸⣿⣿⡇⠀⢠⣿⣿⡿⠃⠀⠀⣸⣿⣿⣿⠁⠀⣾⣿⣿⠇⢸⣿⣿⣿⣿⠏⠀⣾⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⠁⠀⢸⣿⣿⣿⣷⣿⣿⣿⡟⠀⢰⣿⣿⣿⠿⠿⠿⠟⠛⠋⠀⠀⣼⣿⣿⡏⠀⠀⠀⠀⢰⣿⣿⡿⠀⠀⠀⢸⣿⣿⡇⣰⣿⣾⡿⠁⠀⠀⢠⣿⣿⣿⠇⠀⣼⣷⣿⡟⠀⠀⣿⣿⡟⠁⠀⢰⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⣿⠇⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⠁⢀⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⠁⠀⠀⢀⣠⣿⣾⣿⠃⠀⠀⠀⢸⣿⣿⣷⣿⣿⠟⠀⠀⠀⠀⣾⣿⣿⡿⠀⢰⣿⣿⣿⠁⠀⠀⠉⠉⠀⠀⠀⡿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⡟⠀⠀⠀⠀⢸⡿⣿⣿⣿⣿⠇⠀⣼⣷⣿⣿⣥⣤⣤⣶⣶⢶⡆⠀⣿⢾⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃⠀⠀⠀⠀⢸⣿⣿⣿⣻⠏⠀⠀⠀⠀⢸⣯⡿⠽⠃⠀⠾⠾⠿⠃⠀⠀⠀⠀⠀⠀⠀⠈⠛⠛⠛⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⠁⠀⠀⠀⠀⠀⣿⣿⣿⣿⡟⠀⢰⣿⣿⣿⣿⣿⣿⣿⣿⣯⡿⠀⠀⠈⠳⠿⠿⠿⠿⠟⠛⠋⠁⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣻⣿⣿⠇⠀⠀⠀⠀⠀⠀⠹⠿⠿⠾⠁⠀⠈⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⡀⠤⠤⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢠⣞⣿⡿⠟⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣀⣀⣤⣤⣤⣤⣤⣶⣶⣶⠶⠶⠶⠟⠛⠛⠛⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠰⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣠⣤⣤⣤⣴⣶⣶⣶⣿⣿⣿⣿⠿⠿⠿⠛⠛⠛⠋⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣤⣴⣶⣶⣶⣿⣿⣿⣿⣿⣿⡿⠿⠿⠛⠛⠛⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⠿⠿⠟⠛⠛⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
    ]]

		local function dashboard_header()
			local quote = quotes.get_current_quote()
			return logo .. "\n\n" .. quote_formatter.format_quote(quote.text, quote.author)
		end

		return {
			input = { enabled = true },
			dashboard = {
				preset = {
					-- stylua: ignore
					---@type snacks.dashboard.Item[]
					header_hl = "SnacksDashboardHeader", -- You can customize this
					keys = {
						{
							icon = " ",
							key = "ff",
							desc = "Find File",
							action = ":FFFFind",
						},
						{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
						{
							icon = " ",
							key = "g",
							desc = "Find Text",
							action = ":lua require('fff').live_grep()",
						},
						{
							icon = "󰇌 ",
							key = "l",
							desc = "New Quote",
							action = function()
								quotes.random_quote()
								Snacks.dashboard.update()
							end,
						},
						{
							icon = " ",
							key = "r",
							desc = "Recent Files",
							action = ":lua Snacks.dashboard.pick('oldfiles')",
						},
						{ icon = " ", key = "s", desc = "Restore Session", section = "session" },
						{
							icon = "󰒲 ",
							key = "L",
							desc = "Lazy",
							action = ":Lazy",
							enabled = package.loaded.lazy ~= nil,
						},
						{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
					},
				},
				sections = {
					function()
						return { header = dashboard_header(), padding = 2 }
					end,
					{ section = "keys", gap = 1, padding = 1 },
					{ section = "startup" },
				},
			},
			bigfile = { enabled = true },
			notifier = { enabled = true },
			image = { enabled = true },
			zen = { enabled = true },
			picker = {
				-- layout = "telescope",
				formatters = {
					file = "%F",
				},
				win = {
					input = {},
				},
			},
		}
	end,
	config = function(_, opts)
		require("snacks").setup(opts)

		-- Customize dashboard header colors for Tokyo Night
		vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = "#e0af68" })
	end,
}

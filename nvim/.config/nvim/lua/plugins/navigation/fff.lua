return {
	"dmtrKovalenko/fff.nvim",
	enabled = require("toggles").enabled("fff"),
	cmd = {
		"FFFFind",
		"FFFScan",
		"FFFRefreshGit",
		"FFFClearCache",
		"FFFHealth",
		"FFFDebug",
		"FFFOpenLog",
	},
	build = function()
		-- this will download prebuild binary or try to use existing rustup toolchain to build from source
		-- (if you are using lazy you can use gb for rebuilding a plugin if needed)
		require("fff.download").download_or_build_binary()
	end,
	-- if you are using nixos
	-- build = "nix run .#release",
	opts = { -- (optional)
		layout = {
			prompt_position = "top",
		},
		max_threads = 8,
		prompt = "↯ ",
		title = "FFF",
	},
	lazy = true,
	keys = {
		{
			"ff",
			function()
				require("fff").find_files()
			end,
			desc = "FFFind files",
		},
		{
			"<leader>ff",
			function()
				require("fff").find_files()
			end,
			desc = "FFF: find files",
		},
		{
			"<leader>fw",
			function()
				require("fff").live_grep({
					title = "FFFuzzy Grep",
					grep = {
						modes = { "plain", "fuzzy" },
					},
				})
			end,
			desc = "Live fffuzy grep",
		},
	},
}

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
	config = function(_, opts)
		require("fff").setup(opts)

		local ok, preview = pcall(require, "fff.file_picker.preview")
		if not ok then
			return
		end

		function preview.scroll_to_line(line)
			if not preview.state.winid or not vim.api.nvim_win_is_valid(preview.state.winid) then
				return
			end
			if not preview.state.bufnr or not vim.api.nvim_buf_is_valid(preview.state.bufnr) then
				return
			end

			local buffer_lines = vim.api.nvim_buf_line_count(preview.state.bufnr)
			local target_line = math.max(1, math.min(line, buffer_lines))

			pcall(vim.api.nvim_win_call, preview.state.winid, function()
				vim.api.nvim_win_set_cursor(preview.state.winid, { target_line, 0 })
				vim.cmd("normal! zz")
			end)
		end
	end,
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

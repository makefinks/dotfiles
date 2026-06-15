local fff_resume_state = {}

local function setup_fff_resume_fallback()
	local fff = require("fff")
	if fff.resume then
		return
	end

	local ok, picker_ui = pcall(require, "fff.picker_ui")
	if not ok or picker_ui.__dotfiles_resume_fallback then
		return
	end

	local close = picker_ui.close
	local function restore_selection()
		vim.schedule(function()
			if not picker_ui.state or not picker_ui.state.active then
				return
			end

			local item_count = #picker_ui.state.filtered_items
			if item_count == 0 then
				return
			end

			picker_ui.state.cursor = math.min(fff_resume_state.cursor or 1, item_count)
			picker_ui.state.top = math.min(fff_resume_state.top or 1, item_count)

			picker_ui.render_list()
			picker_ui.update_preview()
			picker_ui.update_status()
		end)
	end

	picker_ui.close = function(...)
		if picker_ui.state and picker_ui.state.active then
			fff_resume_state = {
				mode = picker_ui.state.mode,
				query = picker_ui.state.query,
				cursor = picker_ui.state.cursor,
				top = picker_ui.state.top,
				grep_config = picker_ui.state.grep_config,
			}
		end
		return close(...)
	end
	picker_ui.__dotfiles_resume_fallback = true

	function fff.resume()
		if not fff_resume_state.mode and not fff_resume_state.query then
			return false
		end

		if fff_resume_state.mode == "grep" then
			fff.live_grep({
				title = "FFFuzzy Grep",
				query = fff_resume_state.query,
				grep = fff_resume_state.grep_config,
			})
		else
			fff.find_files({ query = fff_resume_state.query })
		end

		restore_selection()
		return true
	end
end

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
		setup_fff_resume_fallback()

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
		{ "<leader>fs", false },
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
		{
			"<leader>f<CR>",
			function()
				require("fff").resume()
			end,
			desc = "FFF: resume last picker",
		},
	},
}

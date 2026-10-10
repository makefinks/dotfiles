local M = {}

local function diff_selected(picker_ui, origin_buf)
	local state = picker_ui.state
	local item = state.active and state.filtered_items[state.cursor] or nil
	if not item then
		return
	end
	if not vim.api.nvim_buf_is_valid(origin_buf) or vim.bo[origin_buf].buftype ~= "" then
		vim.notify("FFF: open the picker from a file buffer to compare files", vim.log.levels.WARN)
		return
	end

	local left = vim.api.nvim_buf_get_name(origin_buf)
	local right = require("fff.utils").canonicalize_fff_path(item.relative_path)
	if left == "" or not right or vim.fn.filereadable(right) ~= 1 then
		vim.notify("FFF: select a file and open the picker from a named file buffer", vim.log.levels.WARN)
		return
	end
	if left == right then
		vim.notify("FFF: select a different file to compare", vim.log.levels.INFO)
		return
	end

	vim.cmd.stopinsert()
	picker_ui.close()
	vim.schedule(function()
		local ok, err = pcall(function()
			local ok_lazy, lazy = pcall(require, "lazy")
			if ok_lazy and lazy.load then
				lazy.load({ plugins = { "codediff.nvim" } })
			end
			require("user.codediff.adapter").open_files(left, right)
		end)
		if not ok then
			vim.notify("FFF: could not open diff: " .. tostring(err), vim.log.levels.ERROR)
		end
	end)
end

function M.setup()
	local picker_ui = require("fff.picker_ui.picker_ui")
	if picker_ui.__dotfiles_diff then
		return
	end
	picker_ui.__dotfiles_diff = true
	local create_ui = picker_ui.create_ui
	picker_ui.create_ui = function(...)
		-- Capture before fff focuses any floating window, including on resume/scoped search.
		local origin_buf = vim.api.nvim_get_current_buf()
		local result = create_ui(...)
		if not result then
			return result
		end
		local function open_diff()
			diff_selected(picker_ui, origin_buf)
		end
		for _, buf in ipairs({ picker_ui.state.input_buf, picker_ui.state.list_buf, picker_ui.state.preview_buf }) do
			if buf and vim.api.nvim_buf_is_valid(buf) then
				vim.keymap.set({ "i", "n" }, "<C-d>", open_diff, {
					buffer = buf,
					silent = true,
					desc = "Diff current file against selected file",
				})
			end
		end
		return result
	end
end

return M

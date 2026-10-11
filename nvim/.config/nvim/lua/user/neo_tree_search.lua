local M = {}
local namespace = vim.api.nvim_create_namespace("UserNeoTreeFilterMatch")

function M.highlight(state)
	local buffer = state.bufnr
	if state.name ~= "filesystem" or not buffer or not vim.api.nvim_buf_is_valid(buffer) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
	local pattern = state.search_pattern
	if not state.tree or not pattern or pattern == "" then
		return
	end

	-- Highlight after rendering: containers insert padding between text pieces.
	local literal = "\\c\\V" .. pattern:gsub("\\", "\\\\")
	for row, line in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)) do
		local node = state.tree:get_node(row)
		if node and (node.type == "file" or node.type == "directory") then
			local name_start = line:find(node.name, 1, true)
			if name_start then
				local offset = 0
				while offset < #node.name do
					local match = vim.fn.matchstrpos(node.name, literal, offset)
					local first, last = match[2], match[3]
					if first < 0 then
						break
					end
					vim.api.nvim_buf_set_extmark(buffer, namespace, row - 1, name_start - 1 + first, {
						end_col = name_start - 1 + last,
						hl_group = "NeoTreeFilterMatch",
						priority = 200,
					})
					offset = last
				end
			end
		end
	end
end

function M.setup()
	vim.api.nvim_set_hl(0, "NeoTreeFilterMatch", { default = true, link = "Search" })
	local group = vim.api.nvim_create_augroup("UserNeoTreeSearch", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			vim.api.nvim_set_hl(0, "NeoTreeFilterMatch", { default = true, link = "Search" })
		end,
	})

	local utils = require("neo-tree.utils")
	if utils._user_filter_debounce then
		return
	end

	-- Neo-tree hardcodes a 100–500 ms delay based on query length.
	local debounce = utils.debounce
	utils.debounce = function(id, fn, frequency_in_ms, strategy, action)
		if id == "filesystem_filter" then
			frequency_in_ms = 50
		end
		return debounce(id, fn, frequency_in_ms, strategy, action)
	end
	utils._user_filter_debounce = true
end

return M

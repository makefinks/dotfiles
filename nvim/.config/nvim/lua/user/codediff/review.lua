local adapter = require("user.codediff.adapter")

local M = {}

local groups = { "conflicts", "unstaged", "staged" }
local namespace = vim.api.nvim_create_namespace("user_codediff_review")
local reviewed_hl = "UserCodeDiffReviewed"
local reviewed_marker_hl = "UserCodeDiffReviewedMarker"
local reviewed_active_marker_hl = "UserCodeDiffReviewedActiveMarker"

local function color_hex(color)
	return string.format("#%06x", color)
end

local function blend(fg, bg, alpha)
	local function channel(color, shift)
		return math.floor(color / shift) % 256
	end

	local red = math.floor(channel(fg, 0x10000) * alpha + channel(bg, 0x10000) * (1 - alpha))
	local green = math.floor(channel(fg, 0x100) * alpha + channel(bg, 0x100) * (1 - alpha))
	local blue = math.floor(channel(fg, 1) * alpha + channel(bg, 1) * (1 - alpha))
	return red * 0x10000 + green * 0x100 + blue
end

local function ensure_highlights()
	local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	local normal_bg = normal.bg or 0x111111
	local accent_bg = 0x56b4e9 -- Okabe-Ito sky blue: colorblind-friendly and distinct from git red/green.
	local marker_fg = 0xe69f00 -- Okabe-Ito amber.
	local bg = blend(accent_bg, normal_bg, 0.32)

	vim.api.nvim_set_hl(0, reviewed_hl, { bg = color_hex(bg) })
	vim.api.nvim_set_hl(0, reviewed_marker_hl, { fg = color_hex(marker_fg), bg = color_hex(bg), bold = true })
	vim.api.nvim_set_hl(0, reviewed_active_marker_hl, { fg = color_hex(marker_fg), bold = true })
end

local function review_key(file_data)
	if not file_data or not file_data.group or not file_data.path then
		return nil
	end

	return file_data.group .. ":" .. file_data.path
end

local function current_file_data(explorer)
	if
		explorer
		and explorer.bufnr
		and vim.api.nvim_buf_is_valid(explorer.bufnr)
		and vim.api.nvim_get_current_buf() == explorer.bufnr
		and explorer.tree
	then
		local node = explorer.tree:get_node()
		if node and node.data and node.data.path and node.data.group then
			return node.data
		end
	end

	if not explorer or not explorer.current_file_path or not explorer.current_file_group then
		return nil
	end

	return explorer.current_selection
		or {
			path = explorer.current_file_path,
			group = explorer.current_file_group,
		}
end

local function get_ordered_files(explorer)
	if not explorer then
		return {}
	end

	local refresh = adapter.explorer_refresh(nil, "get_all_files", {
		notify = false,
	})
	if refresh and explorer.tree then
		local files = {}
		for _, node in ipairs(refresh.get_all_files(explorer.tree)) do
			if node.data and node.data.path and node.data.group then
				files[#files + 1] = node.data
			end
		end

		return files
	end

	local files = {}
	for _, group in ipairs(groups) do
		for _, file in ipairs(explorer.status_result and explorer.status_result[group] or {}) do
			files[#files + 1] = vim.tbl_extend("force", file, { group = group })
		end
	end

	return files
end

function M.get_files_in_range(explorer, start_line, end_line)
	if not explorer or not explorer.tree then
		return {}
	end

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local files = {}
	local seen = {}
	for line = start_line, end_line do
		local node = explorer.tree:get_node(line)
		local data = node and node.data or nil
		if data and data.path and data.group and not data.type then
			local key = review_key(data)
			if key and not seen[key] then
				files[#files + 1] = vim.deepcopy(data)
				seen[key] = true
			end
		end
	end

	return files
end

function M.is_reviewed(explorer, file_data)
	local key = review_key(file_data)
	return key and explorer and explorer._user_reviewed and explorer._user_reviewed[key] or false
end

function M.toggle_current(explorer)
	local file_data = current_file_data(explorer)
	local key = review_key(file_data)
	if not key then
		vim.notify("No CodeDiff file selected to mark reviewed", vim.log.levels.WARN)
		return false
	end

	explorer._user_reviewed = explorer._user_reviewed or {}
	if explorer._user_reviewed[key] then
		explorer._user_reviewed[key] = nil
		return false
	end

	explorer._user_reviewed[key] = true
	return true
end

function M.toggle_files(explorer, files)
	if not explorer or #files == 0 then
		return nil
	end

	explorer._user_reviewed = explorer._user_reviewed or {}
	local should_review = false
	for _, file_data in ipairs(files) do
		if not M.is_reviewed(explorer, file_data) then
			should_review = true
			break
		end
	end

	for _, file_data in ipairs(files) do
		local key = review_key(file_data)
		if key then
			explorer._user_reviewed[key] = should_review or nil
		end
	end

	return should_review
end

function M.clear(explorer)
	if not explorer then
		return
	end

	explorer._user_reviewed = nil
end

function M.get_progress(explorer)
	local files = get_ordered_files(explorer)
	local total = #files
	if total == 0 then
		return nil
	end

	local reviewed = 0
	for _, file_data in ipairs(files) do
		if M.is_reviewed(explorer, file_data) then
			reviewed = reviewed + 1
		end
	end

	return string.format("Reviewed %d/%d", reviewed, total), reviewed, total
end

function M.render(explorer)
	if not explorer or not explorer.bufnr or not vim.api.nvim_buf_is_valid(explorer.bufnr) then
		return
	end

	ensure_highlights()
	vim.api.nvim_buf_clear_namespace(explorer.bufnr, namespace, 0, -1)
	if not explorer._user_reviewed then
		return
	end

	for line = 1, vim.api.nvim_buf_line_count(explorer.bufnr) do
		local node = explorer.tree and explorer.tree:get_node(line) or nil
		if node and node.data and M.is_reviewed(explorer, node.data) then
			local is_selected = node.data.path == explorer.current_file_path
				and node.data.group == explorer.current_file_group
			local line_text = vim.api.nvim_buf_get_lines(explorer.bufnr, line - 1, line, false)[1] or ""
			local opts = {
				end_col = #line_text,
				priority = 10000,
				virt_text = { { "R ", reviewed_active_marker_hl } },
				virt_text_pos = "inline",
			}

			if not is_selected then
				opts.hl_group = reviewed_hl
				opts.hl_mode = "combine"
				opts.line_hl_group = reviewed_hl
				opts.virt_text = { { "R ", reviewed_marker_hl } }
			end

			vim.api.nvim_buf_set_extmark(explorer.bufnr, namespace, line - 1, 0, opts)
		end
	end
end

function M.install_renderer(explorer)
	if not explorer or not explorer.tree or explorer._user_review_renderer_installed then
		return
	end

	local original_render = explorer.tree.render
	explorer.tree.render = function(tree, ...)
		local result = original_render(tree, ...)
		M.render(explorer)
		return result
	end

	explorer._user_review_renderer_installed = true
end

function M.get_namespace()
	return namespace
end

function M.find_unreviewed(explorer, direction)
	direction = direction == -1 and -1 or 1
	local files = get_ordered_files(explorer)
	if #files == 0 then
		return nil
	end

	local current = current_file_data(explorer)
	local current_key = review_key(current)
	local current_index = 1
	for index, file_data in ipairs(files) do
		if review_key(file_data) == current_key then
			current_index = index
			break
		end
	end

	for offset = 1, #files do
		local index = ((current_index - 1 + direction * offset) % #files) + 1
		local file_data = files[index]
		if not M.is_reviewed(explorer, file_data) then
			return file_data
		end
	end

	return nil
end

return M

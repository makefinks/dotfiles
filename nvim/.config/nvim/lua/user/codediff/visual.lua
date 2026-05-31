local M = {}

local function refresh_review_statusline(get_codediff_lifecycle, tabpage, deps)
	if deps.view.refresh_statusline then
		deps.view.refresh_statusline(get_codediff_lifecycle, tabpage)
	end
end

local function get_explorer(get_codediff_lifecycle, tabpage)
	local lifecycle = get_codediff_lifecycle()
	return lifecycle and lifecycle.get_explorer(tabpage) or nil
end

local function get_range()
	return vim.fn.line("v"), vim.fn.line(".")
end

local function leave_visual_mode()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
end

function M.toggle_reviewed(get_codediff_lifecycle, tabpage, deps)
	local start_line, end_line = get_range()
	leave_visual_mode()

	local explorer = get_explorer(get_codediff_lifecycle, tabpage)
	if not explorer then
		return
	end

	local files = deps.review.get_files_in_range(explorer, start_line, end_line)
	deps.review.toggle_files(explorer, files)
	refresh_review_statusline(get_codediff_lifecycle, tabpage, deps)
end

function M.stage(get_codediff_lifecycle, tabpage, deps)
	local start_line, end_line = get_range()
	leave_visual_mode()
	deps.actions.stage_entries(get_codediff_lifecycle, tabpage, start_line, end_line)
end

function M.unstage(get_codediff_lifecycle, tabpage, deps)
	local start_line, end_line = get_range()
	leave_visual_mode()
	deps.actions.unstage_entries(get_codediff_lifecycle, tabpage, start_line, end_line)
end

return M

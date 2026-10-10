local M = {}

local adapter = require("user.codediff.adapter")

local function file_key(session)
	return vim.inspect({
		session.git_root,
		session.original,
		session.modified,
		session.original_revision,
		session.modified_revision,
	})
end

local function save_view(win)
	if win and vim.api.nvim_win_is_valid(win) then
		return vim.api.nvim_win_call(win, vim.fn.winsaveview)
	end
end

local function restore_view(win, view)
	if view and win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_call(win, function()
			vim.fn.winrestview(view)
		end)
	end
end

local function restore_pending(lifecycle, tabpage, session, pending)
	if
		not vim.api.nvim_tabpage_is_valid(tabpage)
		or lifecycle.get_session(tabpage) ~= session
		or session.user_layout_pending ~= pending
	then
		return
	end
	session.user_layout_pending = nil
	if session.layout ~= pending.layout or file_key(session) ~= pending.key then
		return
	end

	local view = pending.view
	if session.layout ~= "inline" then
		restore_view(session.original_win, view.original)
	end
	restore_view(session.modified_win, view.modified)
	if vim.api.nvim_get_current_tabpage() == tabpage then
		local win = view.focus == "original" and session.original_win or session.modified_win
		if view.focus == "external" then
			win = pending.focus_win
		end
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_set_current_win(win)
		end
	end
end

local function install_render_hook(lifecycle)
	if lifecycle.user_layout_render_hook == lifecycle.update_diff_result then
		return
	end
	local update_diff_result = lifecycle.update_diff_result
	lifecycle.update_diff_result = function(tabpage, diff_result, ...)
		local result = update_diff_result(tabpage, diff_result, ...)
		local session = lifecycle.get_session(tabpage)
		local pending = session and session.user_layout_pending
		if pending and diff_result then
			-- Rendering still adjusts focus, folds, and layout after updating the diff.
			vim.schedule(function()
				restore_pending(lifecycle, tabpage, session, pending)
			end)
		end
		return result
	end
	lifecycle.user_layout_render_hook = lifecycle.update_diff_result
end

function M.toggle(get_codediff_lifecycle, tabpage)
	local lifecycle = get_codediff_lifecycle()
	local session = lifecycle and lifecycle.get_session(tabpage)
	if not session or session.user_layout_pending then
		return
	end
	local upstream = adapter.view("Failed to load codediff layout toggle", "toggle_layout")
	if not upstream then
		return
	end
	if session.result_win and vim.api.nvim_win_is_valid(session.result_win) then
		return upstream.toggle_layout(tabpage)
	end

	install_render_hook(lifecycle)
	local key = file_key(session)
	local saved = session.user_layout_views
	if not saved or saved.key ~= key then
		saved = { key = key }
		session.user_layout_views = saved
	end
	local current_win = vim.api.nvim_get_current_win()
	local focus = "external"
	if current_win == session.modified_win then
		focus = "modified"
	elseif current_win == session.original_win then
		focus = "original"
	end
	local current = {
		original = save_view(session.original_win),
		modified = save_view(session.modified_win),
		focus = focus,
	}
	saved[session.layout] = current
	local target = session.layout == "inline" and "side-by-side" or "inline"
	local pending = {
		key = key,
		layout = target,
		view = saved[target] or current,
		focus_win = current_win,
	}
	session.user_layout_pending = pending
	-- Failed/abandoned upstream renders must not leave the mapping locked forever.
	vim.defer_fn(function()
		if lifecycle.get_session(tabpage) == session and session.user_layout_pending == pending then
			session.user_layout_pending = nil
		end
	end, 10000)
	local ok, result = pcall(upstream.toggle_layout, tabpage)
	if not ok or not result then
		session.user_layout_pending = nil
		if not ok then
			vim.notify("Failed to toggle codediff layout: " .. tostring(result), vim.log.levels.ERROR)
		end
	end
end

return M

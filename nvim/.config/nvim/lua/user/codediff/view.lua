local M = {}

local adapter = require("user.codediff.adapter")
local filters = require("user.codediff.filters")
local helpers = require("user.codediff.helpers")
local lsp = require("user.codediff.lsp")
local review = require("user.codediff.review")
local resume = require("user.codediff.resume")

local statusline_state_by_tabpage = {}
local result_zoom_state_by_tabpage = {}

local function get_explorer_winid(explorer)
	if not explorer then
		return nil
	end

	return explorer.split and explorer.split.winid or explorer.winid
end

local function disable_panel_scrollbind(winid)
	if not winid or not vim.api.nvim_win_is_valid(winid) then
		return
	end

	vim.wo[winid].scrollbind = false
	vim.wo[winid].cursorbind = false
end

local function is_effectively_empty_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count == 0 then
		return true
	end

	if line_count == 1 then
		local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
		return line == nil or line == ""
	end

	return false
end

local function reset_one_sided_conflict_view(tabpage)
	local lifecycle = adapter.loaded_lifecycle()
	local session = lifecycle and lifecycle.get_session(tabpage) or nil
	if not session or not session.result_bufnr then
		return
	end

	local original_win = session.original_win
	local modified_win = session.modified_win
	if
		not original_win
		or not modified_win
		or not vim.api.nvim_win_is_valid(original_win)
		or not vim.api.nvim_win_is_valid(modified_win)
	then
		return
	end

	local original_empty = is_effectively_empty_buffer(session.original_bufnr)
	local modified_empty = is_effectively_empty_buffer(session.modified_bufnr)
	if original_empty == modified_empty then
		return
	end

	local current_win = vim.api.nvim_get_current_win()
	for _, winid in ipairs({ original_win, modified_win, session.result_win }) do
		if winid and vim.api.nvim_win_is_valid(winid) then
			vim.wo[winid].scrollbind = false
			pcall(vim.api.nvim_win_set_cursor, winid, { 1, 0 })
		end
	end
	for _, winid in ipairs({ original_win, modified_win, session.result_win }) do
		if winid and vim.api.nvim_win_is_valid(winid) then
			vim.wo[winid].scrollbind = true
		end
	end

	if current_win and vim.api.nvim_win_is_valid(current_win) then
		vim.api.nvim_set_current_win(current_win)
	end
end

local function path_exists(path)
	return path and vim.uv.fs_stat(path) ~= nil
end

local function clamp_cursor_position(bufnr, cursor)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local line = math.min(math.max(cursor[1], 1), math.max(line_count, 1))
	local line_text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
	local col = math.min(math.max(cursor[2], 0), #line_text)
	return { line, col }
end

local function format_marker_progress(current, total)
	local width = 8
	if total == 1 then
		return string.format("%s %d/%d", string.rep("█", width), current, total)
	end

	local marker = 1 + math.floor((current - 1) / (total - 1) * (width - 1))
	return string.format(
		"%s█%s %d/%d",
		string.rep("░", marker - 1),
		string.rep("░", width - marker),
		current,
		total
	)
end

local function get_statusline_tabpage(tabpage)
	if tabpage and vim.api.nvim_tabpage_is_valid(tabpage) then
		return tabpage
	end

	local winid = vim.g.statusline_winid
	if winid and vim.api.nvim_win_is_valid(winid) then
		return vim.api.nvim_win_get_tabpage(winid)
	end

	return vim.api.nvim_get_current_tabpage()
end

local function get_explorer_file_position(explorer)
	if not explorer or not explorer.tree or not explorer.current_file_path or not explorer.current_file_group then
		return nil
	end

	local refresh = adapter.explorer_refresh(nil, "get_all_files", {
		notify = false,
	})
	if not refresh then
		return nil
	end

	local files = refresh.get_all_files(explorer.tree)
	local total = #files
	if total == 0 then
		return nil
	end

	for i, file in ipairs(files) do
		local data = file.data
		if data and data.path == explorer.current_file_path and data.group == explorer.current_file_group then
			return i, total
		end
	end

	return nil
end

function M.save_resume_snapshot(get_codediff_lifecycle, tabpage, cursor)
	resume.save(get_codediff_lifecycle, tabpage, cursor)
end

local function show_added_file_as_editable(tabpage, explorer, file_data)
	if not explorer or not explorer.git_root or not file_data or file_data.status ~= "A" then
		return false
	end

	local lifecycle = adapter.loaded_lifecycle()
	if not lifecycle then
		return false
	end

	local session = lifecycle.get_session(tabpage)
	if not session or session.mode ~= "explorer" then
		return false
	end

	local abs_path = explorer.git_root .. "/" .. file_data.path

	vim.schedule(function()
		local current_session = lifecycle.get_session(tabpage)
		if not current_session then
			return
		end

		if current_session.layout == "inline" then
			local inline_view = adapter.inline_view(nil, "show_single_file", {
				notify = false,
			})
			if inline_view then
				inline_view.show_single_file(tabpage, abs_path, {
					side = "modified",
				})
			end
			return
		end

		local side_by_side = adapter.side_by_side(nil, "show_untracked_file", {
			notify = false,
		})
		if side_by_side then
			side_by_side.show_untracked_file(tabpage, abs_path)
		end
	end)

	return true
end

local function refresh_added_file_after_write(explorer)
	local refresh = adapter.explorer_refresh(nil, "refresh", {
		notify = false,
	})
	if not refresh then
		return
	end

	if explorer.is_hidden then
		explorer._pending_refresh = true
		return
	end

	refresh.refresh(explorer)
end

local function ensure_added_file_stays_staged(tabpage, explorer, file_data)
	if not explorer or not file_data or file_data.status ~= "A" or file_data.group ~= "staged" then
		return
	end

	local lifecycle = adapter.loaded_lifecycle()
	if not lifecycle then
		return
	end

	vim.schedule(function()
		local _, modified_bufnr = lifecycle.get_buffers(tabpage)
		if not modified_bufnr or not vim.api.nvim_buf_is_valid(modified_bufnr) then
			return
		end

		if vim.b[modified_bufnr].codediff_added_file_stage_sync_installed then
			return
		end

		local git = adapter.git(nil, "stage_file", {
			notify = false,
		})
		if not git then
			return
		end

		vim.b[modified_bufnr].codediff_added_file_stage_sync_installed = true
		vim.api.nvim_create_autocmd("BufWritePost", {
			buffer = modified_bufnr,
			desc = "Keep staged added CodeDiff file in sync",
			callback = function()
				local session = lifecycle.get_session(tabpage)
				if not session or session.mode ~= "explorer" then
					return
				end

				local current_explorer = lifecycle.get_explorer(tabpage)
				if not current_explorer or current_explorer ~= explorer then
					return
				end

				local selection = current_explorer.current_selection
				if
					not selection
					or selection.path ~= file_data.path
					or selection.group ~= "staged"
					or selection.status ~= "A"
				then
					return
				end

				git.stage_file(current_explorer.git_root, file_data.path, function(err)
					if helpers.handle_async_error(err) then
						return
					end

					vim.schedule(function()
						refresh_added_file_after_write(current_explorer)
					end)
				end)
			end,
		})
	end)
end

local function get_statusline_file_progress(explorer)
	local current_index, total = get_explorer_file_position(explorer)
	return current_index and format_marker_progress(current_index, total) or nil
end

local function set_statusline_filename(tabpage, explorer, file_data)
	local file_path = file_data and file_data.path or explorer and explorer.current_file_path
	if not file_path or file_path == "" then
		return
	end

	local lifecycle = adapter.loaded_lifecycle()
	if not lifecycle then
		return
	end

	local function apply_statusline_values()
		local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
		local filename = vim.fn.fnamemodify(file_path, ":t")
		local progress = get_statusline_file_progress(explorer)
		local review_progress = review.get_progress(explorer)
		local current_state = statusline_state_by_tabpage[tabpage]
		statusline_state_by_tabpage[tabpage] = {
			name = filename,
			progress = progress,
			review_progress = review_progress,
			hunk_progress = current_state and current_state.hunk_progress or nil,
		}

		for _, bufnr in ipairs({ original_bufnr, modified_bufnr, explorer.bufnr }) do
			if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
				vim.b[bufnr].codediff_status_name = filename
				vim.b[bufnr].codediff_status_progress = progress
				vim.b[bufnr].codediff_review_progress = review_progress
			end
		end

		vim.cmd.redrawstatus()
	end

	apply_statusline_values()

	vim.schedule(function()
		apply_statusline_values()
	end)
end

function M.get_statusline_state(tabpage)
	tabpage = get_statusline_tabpage(tabpage)
	if not tabpage or not vim.api.nvim_tabpage_is_valid(tabpage) then
		return nil
	end

	return statusline_state_by_tabpage[tabpage]
end

function M.is_statusline_active(tabpage)
	tabpage = get_statusline_tabpage(tabpage)
	if not tabpage then
		return false
	end

	local lifecycle = adapter.loaded_lifecycle()
	return lifecycle and lifecycle.get_session(tabpage) ~= nil or false
end

function M.clear_statusline_state(tabpage)
	tabpage = get_statusline_tabpage(tabpage)
	if not tabpage then
		return
	end

	local lifecycle = adapter.loaded_lifecycle()
	local session = lifecycle and lifecycle.get_session(tabpage) or nil
	if session then
		local explorer = lifecycle.get_explorer(tabpage)
		for _, bufnr in pairs({
			session.original_bufnr,
			session.modified_bufnr,
			session.result_bufnr,
			explorer and explorer.bufnr or nil,
		}) do
			if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
				vim.b[bufnr].codediff_status_name = nil
				vim.b[bufnr].codediff_status_progress = nil
				vim.b[bufnr].codediff_review_progress = nil
			end
		end
	end

	statusline_state_by_tabpage[tabpage] = nil
	result_zoom_state_by_tabpage[tabpage] = nil
	vim.cmd.redrawstatus()
	vim.schedule(function()
		vim.cmd.redrawstatus()
	end)
end

local function ensure_editable_added_file_override(tabpage, explorer)
	if not explorer or explorer._user_added_file_override_installed or type(explorer.on_file_select) ~= "function" then
		return
	end

	local original_on_file_select = explorer.on_file_select
	explorer.on_file_select = function(file_data, opts)
		set_statusline_filename(tabpage, explorer, file_data)
		lsp.prepare_selection(explorer, file_data)
		original_on_file_select(file_data, opts)
		lsp.apply_to_session(adapter.loaded_lifecycle(), tabpage)
		if file_data and file_data.group == "conflicts" then
			vim.defer_fn(function()
				if vim.api.nvim_tabpage_is_valid(tabpage) then
					reset_one_sided_conflict_view(tabpage)
				end
			end, 80)
		end

		show_added_file_as_editable(tabpage, explorer, file_data)
		ensure_added_file_stays_staged(tabpage, explorer, file_data)
	end

	explorer._user_added_file_override_installed = true
end

function M.set_explorer_options(get_codediff_lifecycle, tabpage, opts)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle then
		return
	end

	local session = lifecycle.get_session(tabpage)
	local explorer = lifecycle.get_explorer(tabpage)
	if session then
		session.hide_untracked = opts.hide_untracked or false
	end

	if explorer then
		explorer.hide_untracked = opts.hide_untracked or false
		if explorer.hide_untracked then
			explorer.status_result = filters.untracked_status_result(explorer.status_result)
		end
	end
end

-- Open the explorer view for a repo status snapshot, optionally focusing a file.
function M.open_status_explorer(repo, focus_file, opts, get_codediff_lifecycle)
	opts = opts or {}
	local git = adapter.git(nil, "get_status", { notify = false })
	local codediff_view = adapter.view(nil, "create", { notify = false })
	if not git or not codediff_view then
		helpers.notify_error("failed to load or validate codediff modules")
		return
	end

	git.get_status(repo, function(err, status_result)
		if err then
			helpers.notify_error(err)
			return
		end

		if opts.hide_untracked ~= false then
			status_result = filters.untracked_status_result(status_result)
		end

		vim.schedule(function()
			codediff_view.create({
				mode = "explorer",
				git_root = repo,
				original_path = "",
				modified_path = "",
				original_revision = nil,
				modified_revision = nil,
				explorer_data = {
					status_result = status_result,
					focus_file = focus_file,
				},
			}, "")

			local tabpage = vim.api.nvim_get_current_tabpage()
			M.set_explorer_options(get_codediff_lifecycle, tabpage, {
				hide_untracked = opts.hide_untracked ~= false,
			})

			if opts.focus_diff then
				vim.schedule(function()
					M.focus_diff_window(get_codediff_lifecycle, tabpage)
				end)
			end
		end)
	end)
end

-- Close the active codediff tab without losing unsaved work.
function M.close_view(get_codediff_lifecycle)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle then
		return false
	end

	local tabpage = vim.api.nvim_get_current_tabpage()
	if not lifecycle.get_session(tabpage) then
		vim.notify("Current tab is not an active codediff view", vim.log.levels.WARN)
		return false
	end

	if not lifecycle.confirm_close_with_unsaved(tabpage) then
		return false
	end

	M.save_resume_snapshot(get_codediff_lifecycle, tabpage)

	if #vim.api.nvim_list_tabpages() == 1 then
		local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
		vim.cmd("tabnew")
		lifecycle.cleanup_for_quit(tabpage)
		if vim.api.nvim_tabpage_is_valid(tabpage) then
			vim.cmd(tabnr .. "tabclose")
		end
		return true
	end

	vim.cmd("tabclose")
	return true
end

-- Close every active codediff tab so a fresh opener never layers on top of an existing session.
function M.close_all_views(get_codediff_lifecycle)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle then
		return
	end

	local active_tabpages = {}
	for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
		if lifecycle.get_session(tabpage) then
			table.insert(active_tabpages, tabpage)
		end
	end

	if #active_tabpages == 0 then
		return
	end

	for _, tabpage in ipairs(active_tabpages) do
		if not lifecycle.confirm_close_with_unsaved(tabpage) then
			return
		end
		M.save_resume_snapshot(get_codediff_lifecycle, tabpage)
	end

	-- Keep at least one tab alive when every open tab is a codediff session.
	if #active_tabpages == #vim.api.nvim_list_tabpages() then
		vim.cmd("tabnew")
	end

	for _, tabpage in ipairs(active_tabpages) do
		if vim.api.nvim_tabpage_is_valid(tabpage) then
			pcall(vim.cmd, vim.api.nvim_tabpage_get_number(tabpage) .. "tabclose")
		end
	end
end

function M.open_file_from_diff(get_codediff_lifecycle, tabpage)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle then
		return
	end

	tabpage = tabpage or vim.api.nvim_get_current_tabpage()

	local session = lifecycle.get_session(tabpage)
	if not session or session.mode ~= "explorer" then
		return
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
	if current_buf ~= original_bufnr and current_buf ~= modified_bufnr then
		return
	end

	local explorer = lifecycle.get_explorer(tabpage)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local target_path

	if explorer and explorer.git_root and explorer.current_file_path then
		local repo_path = explorer.git_root .. "/" .. explorer.current_file_path
		if path_exists(repo_path) then
			target_path = repo_path
		end
	end

	if not target_path then
		local original_path, modified_path = lifecycle.get_paths(tabpage)
		local preferred_path = current_buf == modified_bufnr and modified_path or original_path
		local fallback_path = current_buf == modified_bufnr and original_path or modified_path

		if path_exists(preferred_path) then
			target_path = preferred_path
		elseif path_exists(fallback_path) then
			target_path = fallback_path
		end
	end

	if not target_path then
		vim.notify("No real file is available for this CodeDiff entry", vim.log.levels.WARN)
		return
	end

	M.save_resume_snapshot(get_codediff_lifecycle, tabpage, cursor)

	M.close_view(get_codediff_lifecycle)

	vim.schedule(function()
		local ok = pcall(vim.cmd.edit, vim.fn.fnameescape(target_path))
		if not ok then
			vim.notify(string.format("Failed to open %s", target_path), vim.log.levels.ERROR)
			return
		end

		local target_bufnr = vim.api.nvim_get_current_buf()
		if not vim.api.nvim_buf_is_valid(target_bufnr) then
			return
		end

		pcall(vim.api.nvim_win_set_cursor, 0, clamp_cursor_position(target_bufnr, cursor))
		pcall(vim.cmd.normal, { args = { "zz" }, bang = true })
	end)
end

function M.resume_last_session(get_codediff_lifecycle)
	resume.resume(get_codediff_lifecycle, {
		focus_diff_window = M.focus_diff_window,
		open_status_explorer = M.open_status_explorer,
		refresh_statusline = M.refresh_statusline,
		select_explorer_file = M.select_explorer_file,
		set_explorer_options = M.set_explorer_options,
		toggle_explorer = M.toggle_explorer,
	})
end

-- Return the explorer object for the current codediff tab, if one exists.
function M.get_explorer(get_codediff_lifecycle, tabpage)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle then
		return nil
	end

	local explorer = lifecycle.get_explorer(tabpage)
	disable_panel_scrollbind(get_explorer_winid(explorer))
	return explorer
end

function M.ensure_explorer_window_state(get_codediff_lifecycle, tabpage)
	local explorer = M.get_explorer(get_codediff_lifecycle, tabpage)
	if not explorer then
		return
	end

	review.install_renderer(explorer)
	ensure_editable_added_file_override(tabpage, explorer)
	lsp.apply_to_session(adapter.loaded_lifecycle(), tabpage)
	set_statusline_filename(tabpage, explorer)
	review.render(explorer)
	disable_panel_scrollbind(get_explorer_winid(explorer))
end

function M.refresh_statusline(get_codediff_lifecycle, tabpage)
	local explorer = M.get_explorer(get_codediff_lifecycle, tabpage)
	if not explorer then
		return
	end

	review.install_renderer(explorer)
	lsp.apply_to_session(adapter.loaded_lifecycle(), tabpage)
	set_statusline_filename(tabpage, explorer)
	review.render(explorer)
end

function M.get_file_position(tabpage)
	tabpage = tabpage or vim.api.nvim_get_current_tabpage()

	local lifecycle = adapter.loaded_lifecycle()
	if not lifecycle then
		return nil
	end

	local session = lifecycle.get_session(tabpage)
	if not session or session.mode ~= "explorer" then
		return nil
	end

	local explorer = lifecycle.get_explorer(tabpage)
	local current_index, total = get_explorer_file_position(explorer)
	if not current_index or not total then
		return nil
	end

	return string.format("%d/%d", current_index, total)
end

function M.get_hunk_progress(tabpage)
	tabpage = tabpage or vim.api.nvim_get_current_tabpage()

	local lifecycle = adapter.loaded_lifecycle()
	if not lifecycle then
		return nil
	end

	local session = lifecycle.get_session(tabpage)
	if not session then
		return nil
	end

	local winid = vim.g.statusline_winid
	if not winid or not vim.api.nvim_win_is_valid(winid) then
		winid = vim.api.nvim_get_current_win()
	end

	local current_buf = vim.api.nvim_win_get_buf(winid)
	local is_original = current_buf == session.original_bufnr
	local is_modified = current_buf == session.modified_bufnr
	local is_result = session.result_bufnr and current_buf == session.result_bufnr
	if not is_original and not is_modified and not is_result then
		local explorer = lifecycle.get_explorer(tabpage)
		local is_explorer = explorer and current_buf == explorer.bufnr
		local fallback_win = session.modified_win or session.original_win
		if not is_explorer or not fallback_win or not vim.api.nvim_win_is_valid(fallback_win) then
			return nil
		end

		winid = fallback_win
		current_buf = vim.api.nvim_win_get_buf(winid)
		is_original = current_buf == session.original_bufnr
		is_modified = current_buf == session.modified_bufnr
		is_result = session.result_bufnr and current_buf == session.result_bufnr
		if not is_original and not is_modified and not is_result then
			return nil
		end
	end

	local changes = session.stored_diff_result and session.stored_diff_result.changes or nil
	if not changes or #changes == 0 then
		local explorer = lifecycle.get_explorer(tabpage)
		local selection = explorer and explorer.current_selection or nil
		return selection and selection.status == "A" and format_marker_progress(1, 1) or nil
	end

	local current_line = vim.api.nvim_win_get_cursor(winid)[1]
	local current_index = 1
	for i, change in ipairs(changes) do
		local range = is_original and change.original or change.modified
		if current_line >= range.start_line then
			current_index = i
		end
	end

	return format_marker_progress(current_index, #changes)
end

function M.get_statusline_hunk_progress(tabpage)
	tabpage = get_statusline_tabpage(tabpage)
	local state = tabpage and statusline_state_by_tabpage[tabpage] or nil
	local progress = M.get_hunk_progress(tabpage)
	if progress then
		if state then
			state.hunk_progress = progress
		end

		return progress
	end

	return state and state.hunk_progress or nil
end

-- Hide/show the explorer while keeping the active diff windows usable.
function M.toggle_explorer(get_codediff_lifecycle, tabpage)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle then
		return
	end

	local explorer = lifecycle.get_explorer(tabpage)
	if not explorer then
		vim.notify("Current tab is not an active codediff explorer", vim.log.levels.WARN)
		return
	end

	local explorer_ui = adapter.explorer("Failed to load codediff explorer", "toggle_visibility")
	if not explorer_ui then
		return
	end

	local explorer_win = explorer.split and explorer.split.winid or explorer.winid
	local is_hidden = explorer.is_hidden

	if
		not is_hidden
		and explorer_win
		and vim.api.nvim_win_is_valid(explorer_win)
		and vim.api.nvim_get_current_win() == explorer_win
	then
		local session = lifecycle.get_session(tabpage)
		local fallback_win = session and (session.modified_win or session.original_win) or nil
		if fallback_win and vim.api.nvim_win_is_valid(fallback_win) then
			vim.api.nvim_set_current_win(fallback_win)
		end
	end

	explorer_ui.toggle_visibility(explorer)

	if is_hidden then
		vim.schedule(function()
			local winid = explorer.split and explorer.split.winid or explorer.winid
			if winid and vim.api.nvim_win_is_valid(winid) then
				disable_panel_scrollbind(winid)
				vim.api.nvim_set_current_win(winid)
			end
		end)
	end
end

-- Refocus the diff pane after opening a file from the explorer.
function M.focus_diff_window(get_codediff_lifecycle, tabpage)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle or type(lifecycle.get_windows) ~= "function" then
		return false
	end

	local original_win, modified_win = lifecycle.get_windows(tabpage)
	local target_win = modified_win

	if not target_win or not vim.api.nvim_win_is_valid(target_win) then
		target_win = original_win
	end

	if not target_win or not vim.api.nvim_win_is_valid(target_win) then
		return false
	end

	vim.api.nvim_set_current_win(target_win)
	return true
end

function M.toggle_result_zoom(get_codediff_lifecycle, tabpage)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle then
		return false
	end

	tabpage = tabpage or vim.api.nvim_get_current_tabpage()
	local session = lifecycle.get_session(tabpage)
	if not session then
		vim.notify("Current tab is not an active codediff view", vim.log.levels.WARN)
		return false
	end

	local result_bufnr, result_win
	if type(lifecycle.get_result) == "function" then
		result_bufnr, result_win = lifecycle.get_result(tabpage)
	else
		result_bufnr, result_win = session.result_bufnr, session.result_win
	end

	if not result_bufnr or not vim.api.nvim_buf_is_valid(result_bufnr) then
		vim.notify("Current CodeDiff view has no merge result buffer", vim.log.levels.WARN)
		return false
	end

	if not result_win or not vim.api.nvim_win_is_valid(result_win) then
		for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
			if vim.api.nvim_win_get_buf(winid) == result_bufnr then
				result_win = winid
				break
			end
		end
	end

	if not result_win or not vim.api.nvim_win_is_valid(result_win) then
		vim.notify("CodeDiff merge result window is not visible", vim.log.levels.WARN)
		return false
	end

	local state = result_zoom_state_by_tabpage[tabpage]
	if state then
		result_zoom_state_by_tabpage[tabpage] = nil
		if state.restore_cmd and state.restore_cmd ~= "" then
			vim.cmd(state.restore_cmd)
		end
		if state.previous_win and vim.api.nvim_win_is_valid(state.previous_win) then
			vim.api.nvim_set_current_win(state.previous_win)
		elseif vim.api.nvim_win_is_valid(result_win) then
			vim.api.nvim_set_current_win(result_win)
		end
		return true
	end

	result_zoom_state_by_tabpage[tabpage] = {
		restore_cmd = vim.fn.winrestcmd(),
		previous_win = vim.api.nvim_get_current_win(),
	}

	vim.api.nvim_set_current_win(result_win)
	vim.cmd("wincmd _")
	vim.cmd("wincmd |")
	return true
end

function M.select_explorer_file(explorer, file_data)
	if not explorer or not file_data then
		return
	end

	disable_panel_scrollbind(get_explorer_winid(explorer))
	explorer.on_file_select(file_data)
	vim.schedule(function()
		disable_panel_scrollbind(get_explorer_winid(explorer))
	end)
end

-- Open the selected explorer node, or expand/collapse groups and directories.
function M.open_explorer_entry(get_codediff_lifecycle, tabpage, explorer)
	if not explorer or not explorer.tree then
		return
	end

	local node = explorer.tree:get_node()
	if not node then
		return
	end

	if node.data and (node.data.type == "group" or node.data.type == "directory") then
		if node:is_expanded() then
			node:collapse()
		else
			node:expand()
		end
		explorer.tree:render()
		return
	end

	if not node.data then
		return
	end

	local same_selection = explorer.current_file_path == node.data.path
		and explorer.current_file_group == node.data.group
	if not same_selection then
		M.select_explorer_file(explorer, node.data)
	end

	vim.schedule(function()
		M.focus_diff_window(get_codediff_lifecycle, tabpage)
	end)
end

function M.install_refresh_filter()
	local refresh = adapter.explorer_refresh(nil, "refresh", {
		notify = false,
	})
	if not refresh or refresh._user_hide_untracked_installed then
		return
	end

	local original_refresh = refresh.refresh
	refresh.refresh = function(explorer, ...)
		local args = { ... }
		if not explorer or not explorer.hide_untracked then
			return original_refresh(explorer, unpack(args))
		end

		return filters.with_untracked_filtered_git(
			{ "get_status", "get_diff_revision", "get_diff_revisions" },
			function(restore)
				if not restore then
					return original_refresh(explorer, unpack(args))
				end

				local ok, result = pcall(original_refresh, explorer, unpack(args))
				restore()
				if not ok then
					error(result)
				end

				return result
			end
		)
	end

	refresh._user_hide_untracked_installed = true
end

return M

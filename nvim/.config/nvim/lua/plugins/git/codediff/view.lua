local M = {}

local helpers = require("plugins.git.codediff.helpers")

local last_resume_snapshot = nil

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

local function find_status_entry(status_result, file_path, preferred_group)
	if not status_result or not file_path then
		return nil
	end

	local search_order = {}
	if preferred_group then
		search_order[#search_order + 1] = preferred_group
	end

	for _, group in ipairs({ "conflicts", "unstaged", "staged" }) do
		if group ~= preferred_group then
			search_order[#search_order + 1] = group
		end
	end

	for _, group in ipairs(search_order) do
		for _, entry in ipairs(status_result[group] or {}) do
			if entry.path == file_path then
				return vim.deepcopy(vim.tbl_extend("force", entry, { group = group }))
			end
		end
	end

	return nil
end

local function capture_resume_snapshot(session, explorer, cursor)
	if not session or session.mode ~= "explorer" or not explorer or not explorer.git_root then
		return
	end

	local file_path = explorer.current_file_path
	local group = explorer.current_file_group
	if not file_path or not group then
		return
	end

	last_resume_snapshot = {
		repo = explorer.git_root,
		file_path = file_path,
		group = group,
		cursor = vim.deepcopy(cursor),
		hide_untracked = session.hide_untracked ~= false,
		explorer_hidden = explorer.is_hidden or false,
	}
end

local function apply_resume_snapshot(get_codediff_lifecycle, snapshot, attempt)
	attempt = attempt or 1
	local max_attempts = 80
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle then
		return
	end

	local tabpage = vim.api.nvim_get_current_tabpage()
	local session = lifecycle.get_session(tabpage)
	local explorer = lifecycle.get_explorer(tabpage)
	if not session or not explorer or session.mode ~= "explorer" then
		if attempt >= max_attempts then
			return
		end

		vim.defer_fn(function()
			apply_resume_snapshot(get_codediff_lifecycle, snapshot, attempt + 1)
		end, 50)
		return
	end

	local selection = find_status_entry(explorer.status_result, snapshot.file_path, snapshot.group)
	if selection then
		M.select_explorer_file(explorer, selection)
	end

	vim.defer_fn(function()
		local current_lifecycle = get_codediff_lifecycle()
		if not current_lifecycle then
			return
		end

		local current_tabpage = vim.api.nvim_get_current_tabpage()
		local current_session = current_lifecycle.get_session(current_tabpage)
		local current_explorer = current_lifecycle.get_explorer(current_tabpage)
		if not current_session or not current_explorer or current_session.mode ~= "explorer" then
			return
		end

		if snapshot.explorer_hidden and not current_explorer.is_hidden then
			M.toggle_explorer(get_codediff_lifecycle, current_tabpage)
		end

		if not M.focus_diff_window(get_codediff_lifecycle, current_tabpage) then
			return
		end

		local current_win = vim.api.nvim_get_current_win()
		if not vim.api.nvim_win_is_valid(current_win) then
			return
		end

		local current_bufnr = vim.api.nvim_win_get_buf(current_win)
		if not (current_bufnr and vim.api.nvim_buf_is_valid(current_bufnr)) then
			return
		end

		pcall(vim.api.nvim_win_set_cursor, current_win, clamp_cursor_position(current_bufnr, snapshot.cursor))
		last_resume_snapshot = snapshot
	end, 80)
end

local function show_added_file_as_editable(tabpage, explorer, file_data)
	if not explorer or not explorer.git_root or not file_data or file_data.status ~= "A" then
		return false
	end

	local lifecycle = helpers.get_loaded_module("codediff.ui.lifecycle")
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
			local inline_view = helpers.require_module("codediff.ui.view.inline_view", nil, {
				notify = false,
				functions = "show_single_file",
			})
			if inline_view then
				inline_view.show_single_file(tabpage, abs_path, {
					side = "modified",
				})
			end
			return
		end

		local side_by_side = helpers.require_module("codediff.ui.view.side_by_side", nil, {
			notify = false,
			functions = "show_untracked_file",
		})
		if side_by_side then
			side_by_side.show_untracked_file(tabpage, abs_path)
		end
	end)

	return true
end

local function refresh_added_file_after_write(explorer)
	local refresh = helpers.require_module("codediff.ui.explorer.refresh", nil, {
		notify = false,
		functions = "refresh",
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

	local lifecycle = helpers.get_loaded_module("codediff.ui.lifecycle")
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

		local git = helpers.require_module("codediff.core.git", nil, {
			notify = false,
			functions = "stage_file",
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

local function ensure_editable_added_file_override(tabpage, explorer)
	if not explorer or explorer._user_added_file_override_installed or type(explorer.on_file_select) ~= "function" then
		return
	end

	local original_on_file_select = explorer.on_file_select
	explorer.on_file_select = function(file_data, opts)
		original_on_file_select(file_data, opts)

		show_added_file_as_editable(tabpage, explorer, file_data)
		ensure_added_file_stays_staged(tabpage, explorer, file_data)
	end

	explorer._user_added_file_override_installed = true
end

local function set_explorer_options(get_codediff_lifecycle, tabpage, opts)
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
			explorer.status_result = helpers.filter_untracked_status_result(explorer.status_result)
		end
	end
end

-- Open the explorer view for a repo status snapshot, optionally focusing a file.
function M.open_status_explorer(repo, focus_file, opts, get_codediff_lifecycle)
	opts = opts or {}
	local codediff_git, view = helpers.get_codediff_modules()
	if not codediff_git or not view then
		return
	end

	codediff_git.get_status(repo, function(err, status_result)
		if err then
			helpers.notify_error(err)
			return
		end

		if opts.hide_untracked ~= false then
			status_result = helpers.filter_untracked_status_result(status_result)
		end

		vim.schedule(function()
			view.create({
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
			set_explorer_options(get_codediff_lifecycle, tabpage, {
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
		return
	end

	local tabpage = vim.api.nvim_get_current_tabpage()
	if not lifecycle.get_session(tabpage) then
		vim.notify("Current tab is not an active codediff view", vim.log.levels.WARN)
		return
	end

	if not lifecycle.confirm_close_with_unsaved(tabpage) then
		return
	end

	if #vim.api.nvim_list_tabpages() == 1 then
		local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
		vim.cmd("tabnew")
		lifecycle.cleanup_for_quit(tabpage)
		if vim.api.nvim_tabpage_is_valid(tabpage) then
			vim.cmd(tabnr .. "tabclose")
		end
		return
	end

	vim.cmd("tabclose")
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

	capture_resume_snapshot(session, explorer, cursor)

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
	end)
end

function M.resume_last_session(get_codediff_lifecycle)
	local snapshot = last_resume_snapshot
	if not snapshot then
		vim.notify("No previous CodeDiff session to resume", vim.log.levels.WARN)
		return
	end

	if not path_exists(snapshot.repo) then
		vim.notify(string.format("CodeDiff repo is no longer available: %s", snapshot.repo), vim.log.levels.WARN)
		return
	end

	M.open_status_explorer(snapshot.repo, snapshot.file_path, {
		hide_untracked = snapshot.hide_untracked,
		focus_diff = true,
	}, get_codediff_lifecycle)

	vim.defer_fn(function()
		apply_resume_snapshot(get_codediff_lifecycle, snapshot)
	end, 80)
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

	ensure_editable_added_file_override(tabpage, explorer)
	disable_panel_scrollbind(get_explorer_winid(explorer))
end

function M.get_file_position(tabpage)
	tabpage = tabpage or vim.api.nvim_get_current_tabpage()

	local lifecycle = helpers.get_loaded_module("codediff.ui.lifecycle")
	if not lifecycle then
		return nil
	end

	local session = lifecycle.get_session(tabpage)
	if not session or session.mode ~= "explorer" then
		return nil
	end

	local explorer = lifecycle.get_explorer(tabpage)
	if not explorer or not explorer.tree or not explorer.current_file_path or not explorer.current_file_group then
		return nil
	end

	local refresh = helpers.require_module("codediff.ui.explorer.refresh", nil, {
		notify = false,
		functions = "get_all_files",
	})
	if not refresh then
		return nil
	end

	local files = refresh.get_all_files(explorer.tree)
	local total = #files
	if total == 0 then
		return nil
	end

	local current_index = nil
	for i, file in ipairs(files) do
		local data = file.data
		if data and data.path == explorer.current_file_path and data.group == explorer.current_file_group then
			current_index = i
			break
		end
	end

	if not current_index then
		return nil
	end

	return string.format("%d/%d", current_index, total)
end

function M.echo_file_position(tabpage)
	local position = M.get_file_position(tabpage)
	if not position then
		return
	end

	vim.api.nvim_echo({ { string.format("%s files", position), "ModeMsg" } }, false, {})
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

	local explorer_ui = helpers.require_module("codediff.ui.explorer", "Failed to load codediff explorer", {
		functions = "toggle_visibility",
	})
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
	local refresh = helpers.require_module("codediff.ui.explorer.refresh", nil, {
		notify = false,
		functions = "refresh",
	})
	if not refresh or refresh._user_hide_untracked_installed then
		return
	end

	local original_refresh = refresh.refresh
	refresh.refresh = function(explorer, ...)
		if not explorer or not explorer.hide_untracked then
			return original_refresh(explorer, ...)
		end

		local git = helpers.require_module("codediff.core.git", nil, {
			notify = false,
			functions = "get_status",
		})
		if not git then
			return original_refresh(explorer, ...)
		end

		local original_get_status = git.get_status
		git.get_status = function(git_root, callback)
			return original_get_status(git_root, function(err, status_result)
				callback(err, helpers.filter_untracked_status_result(status_result))
			end)
		end

		local ok, result = pcall(original_refresh, explorer, ...)
		git.get_status = original_get_status
		if not ok then
			error(result)
		end

		return result
	end

	refresh._user_hide_untracked_installed = true
end

return M

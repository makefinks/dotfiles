local filters = require("user.codediff.filters")
local review = require("user.codediff.review")

local M = {}

local SNAPSHOT_VERSION = 1
local last_resume_snapshot = nil

local function path_exists(path)
	return path and vim.uv.fs_stat(path) ~= nil
end

local function get_state_path()
	if vim.g.user_codediff_resume_path and vim.g.user_codediff_resume_path ~= "" then
		return vim.g.user_codediff_resume_path
	end

	return table.concat({ vim.fn.stdpath("state"), "codediff-review", "resume.json" }, "/")
end

local function clear_persisted_snapshot()
	pcall(vim.fn.delete, get_state_path())
end

local function normalize_cursor(cursor)
	if type(cursor) ~= "table" then
		return { 1, 0 }
	end

	return {
		type(cursor[1]) == "number" and cursor[1] or 1,
		type(cursor[2]) == "number" and cursor[2] or 0,
	}
end

local function normalize_snapshot(snapshot)
	if type(snapshot) ~= "table" then
		return nil
	end

	if type(snapshot.repo) ~= "string" or snapshot.repo == "" then
		return nil
	end

	if type(snapshot.file_path) ~= "string" or snapshot.file_path == "" then
		return nil
	end

	if type(snapshot.group) ~= "string" or snapshot.group == "" then
		return nil
	end

	return {
		repo = snapshot.repo,
		file_path = snapshot.file_path,
		group = snapshot.group,
		cursor = normalize_cursor(snapshot.cursor),
		reviewed = type(snapshot.reviewed) == "table" and snapshot.reviewed or nil,
		hide_untracked = snapshot.hide_untracked ~= false,
		explorer_hidden = snapshot.explorer_hidden == true,
		original_revision = type(snapshot.original_revision) == "string" and snapshot.original_revision or nil,
		modified_revision = type(snapshot.modified_revision) == "string" and snapshot.modified_revision or nil,
	}
end

local function load_persisted_snapshot()
	local path = get_state_path()
	if not path_exists(path) then
		return nil
	end

	local ok_read, lines = pcall(vim.fn.readfile, path)
	if not ok_read then
		clear_persisted_snapshot()
		return nil
	end

	local ok_decode, payload = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok_decode or type(payload) ~= "table" or payload.version ~= SNAPSHOT_VERSION then
		clear_persisted_snapshot()
		return nil
	end

	local snapshot = normalize_snapshot(payload.snapshot)
	if not snapshot then
		clear_persisted_snapshot()
	end

	return snapshot
end

local function persist_snapshot(snapshot)
	local path = get_state_path()
	local dir = vim.fn.fnamemodify(path, ":h")
	local payload = {
		version = SNAPSHOT_VERSION,
		saved_at = os.time(),
		snapshot = snapshot,
	}

	local ok_encode, encoded = pcall(vim.json.encode, payload)
	if not ok_encode then
		return
	end

	local ok_write = pcall(function()
		vim.fn.mkdir(dir, "p")
		vim.fn.writefile({ encoded }, path)
	end)

	if not ok_write then
		vim.notify("Failed to persist CodeDiff resume state", vim.log.levels.WARN)
	end
end

local function is_git_repo(path)
	if not path_exists(path) then
		return false
	end

	vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--show-toplevel" })
	return vim.v.shell_error == 0
end

local function with_cwd(path, callback)
	local previous_cwd = vim.fn.getcwd()
	local ok, err = pcall(vim.fn.chdir, path)
	if not ok then
		vim.notify(string.format("Failed to enter CodeDiff repo: %s", err), vim.log.levels.ERROR)
		return false
	end

	local callback_ok, callback_err = pcall(callback)
	pcall(vim.fn.chdir, previous_cwd)
	if not callback_ok then
		error(callback_err)
	end

	return true
end

local function open_revision_snapshot_command(snapshot)
	local original_revision = snapshot.original_revision
	local modified_revision = snapshot.modified_revision
	if not original_revision then
		return false
	end

	local args = { vim.fn.fnameescape(original_revision) }
	if modified_revision and modified_revision ~= "WORKING" then
		args[#args + 1] = vim.fn.fnameescape(modified_revision)
	end

	return with_cwd(snapshot.repo, function()
		vim.cmd("CodeDiff " .. table.concat(args, " "))
	end)
end

local function open_revision_snapshot(snapshot)
	if snapshot.hide_untracked == false then
		return open_revision_snapshot_command(snapshot)
	end

	local ok, restore_git = filters.with_untracked_filtered_git(
		{ "get_diff_revision", "get_diff_revisions" },
		function(restore)
			if not restore then
				return open_revision_snapshot_command(snapshot)
			end

			local group = vim.api.nvim_create_augroup("user_codediff_resume_filter", { clear = true })
			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "CodeDiffOpen",
				once = true,
				callback = restore,
			})

			vim.defer_fn(restore, 10000)
			return open_revision_snapshot_command(snapshot)
		end
	)
	if not ok and restore_git then
		restore_git()
	end

	return ok
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

	return {
		repo = explorer.git_root,
		file_path = file_path,
		group = group,
		cursor = vim.deepcopy(cursor),
		reviewed = vim.deepcopy(explorer._user_reviewed),
		hide_untracked = session.hide_untracked ~= false,
		explorer_hidden = explorer.is_hidden or false,
		original_revision = explorer.base_revision,
		modified_revision = explorer.target_revision,
	}
end

local function get_resume_cursor(session)
	local current_win = vim.api.nvim_get_current_win()
	if current_win and vim.api.nvim_win_is_valid(current_win) then
		local current_buf = vim.api.nvim_win_get_buf(current_win)
		if
			current_buf == session.original_bufnr
			or current_buf == session.modified_bufnr
			or current_buf == session.result_bufnr
		then
			return vim.api.nvim_win_get_cursor(current_win)
		end
	end

	for _, winid in ipairs({ session.modified_win, session.original_win, session.result_win }) do
		if winid and vim.api.nvim_win_is_valid(winid) then
			return vim.api.nvim_win_get_cursor(winid)
		end
	end

	return { 1, 0 }
end

function M.save(get_codediff_lifecycle, tabpage, cursor)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle then
		return
	end

	tabpage = tabpage or vim.api.nvim_get_current_tabpage()
	local session = lifecycle.get_session(tabpage)
	local explorer = lifecycle.get_explorer(tabpage)
	if not session or not explorer or session.mode ~= "explorer" then
		return
	end
	if session._user_resume_snapshot_saved and not cursor then
		return
	end

	local snapshot = capture_resume_snapshot(session, explorer, cursor or get_resume_cursor(session))
	if not snapshot then
		return
	end

	last_resume_snapshot = snapshot
	persist_snapshot(snapshot)
	session._user_resume_snapshot_saved = true
end

local function apply_snapshot(get_codediff_lifecycle, snapshot, deps, attempt)
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
			apply_snapshot(get_codediff_lifecycle, snapshot, deps, attempt + 1)
		end, 50)
		return
	end

	local selection = find_status_entry(explorer.status_result, snapshot.file_path, snapshot.group)
	explorer._user_reviewed = vim.deepcopy(snapshot.reviewed)
	review.install_renderer(explorer)
	if selection then
		deps.select_explorer_file(explorer, selection)
	else
		review.render(explorer)
	end

	if deps.refresh_statusline then
		deps.refresh_statusline(get_codediff_lifecycle, tabpage)
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

		current_explorer._user_reviewed = vim.deepcopy(snapshot.reviewed)
		review.install_renderer(current_explorer)
		review.render(current_explorer)
		if deps.refresh_statusline then
			deps.refresh_statusline(get_codediff_lifecycle, current_tabpage)
		end

		if snapshot.explorer_hidden and not current_explorer.is_hidden then
			deps.toggle_explorer(get_codediff_lifecycle, current_tabpage)
		end

		if not deps.focus_diff_window(get_codediff_lifecycle, current_tabpage) then
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

function M.resume(get_codediff_lifecycle, deps)
	local snapshot = last_resume_snapshot or load_persisted_snapshot()
	if not snapshot then
		vim.notify("No previous CodeDiff session to resume", vim.log.levels.WARN)
		return
	end

	if not is_git_repo(snapshot.repo) then
		vim.notify(string.format("CodeDiff repo is no longer available: %s", snapshot.repo), vim.log.levels.WARN)
		M.clear_persisted()
		return
	end

	last_resume_snapshot = snapshot

	if snapshot.original_revision then
		if not open_revision_snapshot(snapshot) then
			M.clear_persisted()
			return
		end
	else
		deps.open_status_explorer(snapshot.repo, snapshot.file_path, {
			hide_untracked = snapshot.hide_untracked,
			focus_diff = true,
		}, get_codediff_lifecycle)
	end

	vim.defer_fn(function()
		local lifecycle = get_codediff_lifecycle()
		local tabpage = vim.api.nvim_get_current_tabpage()
		if lifecycle and lifecycle.get_session(tabpage) then
			deps.set_explorer_options(get_codediff_lifecycle, tabpage, {
				hide_untracked = snapshot.hide_untracked,
			})
		end

		apply_snapshot(get_codediff_lifecycle, snapshot, deps)
	end, 80)
end

function M.clear_persisted()
	last_resume_snapshot = nil
	clear_persisted_snapshot()
end

function M.forget_memory()
	last_resume_snapshot = nil
end

last_resume_snapshot = load_persisted_snapshot()

return M

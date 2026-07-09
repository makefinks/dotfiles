local M = {}

local namespace = vim.api.nvim_create_namespace("user_codediff_conflict_labels")
local navigation_sync_installed = false
local result_follow_installed = false

local function set_highlights()
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictLabel", {
		fg = "#10131A",
		bg = "#F97316",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictLineNr", {
		fg = "#FB923C",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictIncoming", {
		fg = "#38BDF8",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictCurrent", {
		fg = "#A78BFA",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictResult", {
		fg = "#4ADE80",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictIncomingLine", { bg = "#123B4A" })
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictCurrentLine", { bg = "#30264F" })
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictResultLine", { bg = "#3D3217" })
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictIncomingSign", { fg = "#38BDF8" })
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictCurrentSign", { fg = "#A78BFA" })
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictResultSign", { fg = "#FBBF24" })
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictIncomingAction", {
		fg = "#FFFFFF",
		bg = "#0072B2",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictCurrentAction", {
		fg = "#111827",
		bg = "#CC79A7",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictCombineAction", {
		fg = "#111827",
		bg = "#F0E442",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictIgnoreAction", {
		fg = "#FFFFFF",
		bg = "#D55E00",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictUnresolvedAction", {
		fg = "#111827",
		bg = "#F0E442",
	})
end

local function escape_statusline_text(text)
	return text:gsub("%%", "%%%%")
end

local function get_git_name(git_root, args, fallback)
	if not git_root or git_root == "" then
		return fallback
	end

	local result = vim.fn.systemlist(vim.list_extend({ "git", "-C", git_root }, args))
	if vim.v.shell_error ~= 0 or not result[1] or result[1] == "" then
		return fallback
	end

	return result[1]
end

local function get_branch_labels(session)
	if session._user_conflict_branch_labels then
		return session._user_conflict_branch_labels
	end

	local labels = {
		current = get_git_name(session.git_root, { "branch", "--show-current" }, "HEAD"),
		incoming = get_git_name(
			session.git_root,
			{ "name-rev", "--name-only", "--no-undefined", "MERGE_HEAD" },
			"THEIRS"
		),
	}
	session._user_conflict_branch_labels = labels
	return labels
end

local function set_conflict_window_ui(winid, highlight, label)
	if not (winid and vim.api.nvim_win_is_valid(winid)) then
		return
	end

	vim.wo[winid].number = true
	vim.wo[winid].relativenumber = false
	vim.wo[winid].winbar = string.format("%%#%s# %s %%*", highlight, escape_statusline_text(label))
end

function M.apply_session_ui(session)
	if not session or not session.result_win then
		return
	end

	local labels = get_branch_labels(session)
	local config = require("codediff.config").options.diff
	local original_is_current = config.conflict_ours_position == "left"

	set_conflict_window_ui(
		session.original_win,
		original_is_current and "UserCodeDiffConflictCurrent" or "UserCodeDiffConflictIncoming",
		original_is_current and ("CURRENT · " .. labels.current) or ("INCOMING · " .. labels.incoming)
	)
	set_conflict_window_ui(
		session.modified_win,
		original_is_current and "UserCodeDiffConflictIncoming" or "UserCodeDiffConflictCurrent",
		original_is_current and ("INCOMING · " .. labels.incoming) or ("CURRENT · " .. labels.current)
	)
	set_conflict_window_ui(session.result_win, "UserCodeDiffConflictResult", "RESULT · EDIT HERE")
end

local function clear_session_labels(session)
	for _, bufnr in ipairs({ session.original_bufnr, session.modified_bufnr, session.result_bufnr }) do
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
		end
	end
end

local function place_hunk(bufnr, start_line, end_line, line_hl_group, sign_hl_group, actions)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if start_line < 0 or start_line >= line_count then
		return
	end

	for line = start_line, math.min(end_line, line_count) - 1 do
		vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
			line_hl_group = line_hl_group,
			sign_text = "▌",
			sign_hl_group = sign_hl_group,
			number_hl_group = "UserCodeDiffConflictLineNr",
			priority = 200,
		})
	end

	vim.api.nvim_buf_set_extmark(bufnr, namespace, start_line, 0, {
		virt_lines = { actions },
		virt_lines_above = true,
		priority = 250,
	})
end

local function place_result_hunk(session, block, tracking)
	if not session.result_bufnr or not vim.api.nvim_buf_is_valid(session.result_bufnr) or not block.extmark_id then
		return
	end

	local mark = vim.api.nvim_buf_get_extmark_by_id(
		session.result_bufnr,
		tracking.tracking_ns,
		block.extmark_id,
		{ details = true }
	)
	if mark and #mark >= 2 then
		place_hunk(
			session.result_bufnr,
			mark[1],
			mark[3] and mark[3].end_row or mark[1] + 1,
			"UserCodeDiffConflictResultLine",
			"UserCodeDiffConflictResultSign",
			{
				{ " ? UNRESOLVED ", "UserCodeDiffConflictUnresolvedAction" },
				{ "  ↓ INCOMING <leader>ct ", "UserCodeDiffConflictIncomingAction" },
				{ "  ↓ CURRENT <leader>co ", "UserCodeDiffConflictCurrentAction" },
				{ "  ⇄ COMBINE <leader>cb ", "UserCodeDiffConflictCombineAction" },
			}
		)
	end
end

local function get_current_conflict(session, tracking)
	local current_bufnr = vim.api.nvim_get_current_buf()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	if current_bufnr == session.result_bufnr then
		return tracking.find_conflict_at_cursor_in_result(session, cursor_line)
	end

	local side = current_bufnr == session.original_bufnr and "left"
		or current_bufnr == session.modified_bufnr and "right"
		or nil
	return side and tracking.find_conflict_at_cursor(session, cursor_line, side, false) or nil
end

local function focus_result_block(session, tracking, block)
	if not (session.result_win and vim.api.nvim_win_is_valid(session.result_win)) then
		return
	end

	local result_line = tracking.get_block_start_line(session, block, session.result_bufnr)
	if not result_line then
		return
	end

	local scrollbind = vim.wo[session.result_win].scrollbind
	vim.wo[session.result_win].scrollbind = false
	pcall(vim.api.nvim_win_set_cursor, session.result_win, { result_line, 0 })
	vim.api.nvim_win_call(session.result_win, function()
		vim.cmd("normal! zz")
	end)
	vim.wo[session.result_win].scrollbind = scrollbind
end

function M.resolve_from_result(tabpage, action_name)
	local lifecycle = require("codediff.ui.lifecycle")
	local tracking = require("codediff.ui.conflict.tracking")
	local actions = require("codediff.ui.conflict.actions")
	local session = lifecycle.get_session(tabpage)
	if not session or not session.result_win or not vim.api.nvim_win_is_valid(session.result_win) then
		return false
	end

	local block = get_current_conflict(session, tracking)
	if not block then
		vim.notify("[codediff] No active conflict at cursor position", vim.log.levels.INFO)
		return false
	end

	local source_win = action_name == "current" and session.modified_win or session.original_win
	local source_bufnr = action_name == "current" and session.modified_bufnr or session.original_bufnr
	local source_line = tracking.get_block_start_line(session, block, source_bufnr)
	local action = ({
		incoming = actions.accept_incoming,
		current = actions.accept_current,
		both = actions.accept_both,
		discard = actions.discard,
	})[action_name]
	if not (source_win and vim.api.nvim_win_is_valid(source_win) and source_line and action) then
		return false
	end

	vim.api.nvim_set_current_win(source_win)
	vim.api.nvim_win_set_cursor(source_win, { source_line, 0 })
	local ok = action(tabpage)

	if vim.api.nvim_win_is_valid(session.result_win) then
		focus_result_block(session, tracking, block)
		vim.api.nvim_set_current_win(session.result_win)
	end

	return ok
end

local function set_result_keymaps(session)
	if not session.result_bufnr or not vim.api.nvim_buf_is_valid(session.result_bufnr) or not session.result_win then
		return
	end

	local tabpage = vim.api.nvim_win_get_tabpage(session.result_win)
	for lhs, action_name in pairs({
		["<leader>ct"] = "incoming",
		["<leader>co"] = "current",
		["<leader>cb"] = "both",
		["<leader>cx"] = "discard",
	}) do
		vim.keymap.set("n", lhs, function()
			M.resolve_from_result(tabpage, action_name)
		end, {
			buffer = session.result_bufnr,
			desc = "Resolve current merge conflict from result",
			silent = true,
		})
	end
end

function M.sync_current_conflict(tabpage)
	local lifecycle = require("codediff.ui.lifecycle")
	local ok_tracking, tracking = pcall(require, "codediff.ui.conflict.tracking")
	local session = lifecycle.get_session(tabpage)
	if not ok_tracking or not session or not session.result_win then
		return
	end

	local block = get_current_conflict(session, tracking)
	if not block then
		return
	end

	local panes = {
		{ winid = session.original_win, bufnr = session.original_bufnr },
		{ winid = session.modified_win, bufnr = session.modified_bufnr },
		{ winid = session.result_win, bufnr = session.result_bufnr },
	}
	local scrollbind = {}

	for _, pane in ipairs(panes) do
		if pane.winid and vim.api.nvim_win_is_valid(pane.winid) then
			scrollbind[pane.winid] = vim.wo[pane.winid].scrollbind
			vim.wo[pane.winid].scrollbind = false
		end
	end

	for _, pane in ipairs(panes) do
		if pane.winid and vim.api.nvim_win_is_valid(pane.winid) then
			local line = tracking.get_block_start_line(session, block, pane.bufnr)
			if line then
				pcall(vim.api.nvim_win_set_cursor, pane.winid, { line, 0 })
				vim.api.nvim_win_call(pane.winid, function()
					vim.cmd("normal! zz")
				end)
			end
		end
	end

	for winid, enabled in pairs(scrollbind) do
		if vim.api.nvim_win_is_valid(winid) then
			vim.wo[winid].scrollbind = enabled
		end
	end
end

local function install_navigation_sync()
	local ok_navigation, navigation = pcall(require, "codediff.ui.conflict.navigation")
	if not ok_navigation or navigation_sync_installed then
		return
	end

	for _, direction in ipairs({ "next", "prev" }) do
		local name = "navigate_" .. direction .. "_conflict"
		local original = navigation[name]
		if type(original) == "function" then
			navigation[name] = function(tabpage)
				original(tabpage)
				M.sync_current_conflict(tabpage)
			end
		end
	end

	navigation_sync_installed = true
end

local function install_result_follow()
	local ok_actions, actions = pcall(require, "codediff.ui.conflict.actions")
	if not ok_actions or result_follow_installed then
		return
	end

	local lifecycle = require("codediff.ui.lifecycle")
	local tracking = require("codediff.ui.conflict.tracking")
	for _, action_name in ipairs({ "accept_incoming", "accept_current", "accept_both", "discard" }) do
		local original = actions[action_name]
		if type(original) == "function" then
			actions[action_name] = function(tabpage)
				local session = lifecycle.get_session(tabpage)
				local block = session and get_current_conflict(session, tracking) or nil
				local ok = original(tabpage)
				if ok and session and block then
					focus_result_block(session, tracking, block)
				end
				return ok
			end
		end
	end

	result_follow_installed = true
end

local function render_labels(session, tracking)
	if not session or not session.conflict_blocks then
		return
	end

	M.apply_session_ui(session)
	set_result_keymaps(session)
	clear_session_labels(session)

	for _, block in ipairs(session.conflict_blocks) do
		if tracking.is_block_active(session, block) then
			place_hunk(
				session.original_bufnr,
				block.output1_range.start_line - 1,
				block.output1_range.end_line - 1,
				"UserCodeDiffConflictIncomingLine",
				"UserCodeDiffConflictIncomingSign",
				{
					{ " ↓ ACCEPT INCOMING <leader>ct ", "UserCodeDiffConflictIncomingAction" },
					{ "  ⇄ COMBINE <leader>cb ", "UserCodeDiffConflictCombineAction" },
					{ "  × IGNORE <leader>cx ", "UserCodeDiffConflictIgnoreAction" },
				}
			)
			place_hunk(
				session.modified_bufnr,
				block.output2_range.start_line - 1,
				block.output2_range.end_line - 1,
				"UserCodeDiffConflictCurrentLine",
				"UserCodeDiffConflictCurrentSign",
				{
					{ " ↓ ACCEPT CURRENT <leader>co ", "UserCodeDiffConflictCurrentAction" },
					{ "  ⇄ COMBINE <leader>cb ", "UserCodeDiffConflictCombineAction" },
					{ "  × IGNORE <leader>cx ", "UserCodeDiffConflictIgnoreAction" },
				}
			)
			place_result_hunk(session, block, tracking)
		end
	end
end

function M.install(group)
	set_highlights()

	if group then
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = group,
			callback = set_highlights,
		})
		vim.api.nvim_create_autocmd("User", {
			group = group,
			pattern = "CodeDiffClose",
			callback = function(args)
				local lifecycle = require("codediff.ui.lifecycle")
				local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
				local session = lifecycle.get_session(tabpage)
				if session then
					clear_session_labels(session)
				end
			end,
		})
	end

	local ok_signs, signs = pcall(require, "codediff.ui.conflict.signs")
	local ok_tracking, tracking = pcall(require, "codediff.ui.conflict.tracking")
	if not ok_signs or not ok_tracking or signs._user_conflict_labels_installed then
		return
	end

	install_navigation_sync()
	install_result_follow()

	local original_refresh = signs.refresh_all_conflict_signs
	signs.refresh_all_conflict_signs = function(session, ...)
		local result = { original_refresh(session, ...) }
		render_labels(session, tracking)
		return unpack(result)
	end

	signs._user_conflict_labels_installed = true
end

function M.get_namespace()
	return namespace
end

return M

local M = {}

local adapter = require("user.codediff.adapter")
local lsp = require("user.codediff.lsp")
local visual = require("user.codediff.visual")

local tracked_keymap_buffers = {}
local overridden_buffer_keymaps = {}

local function get_buffer_keymap(bufnr, mode, lhs)
	if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
		return nil
	end

	local mapping
	vim.api.nvim_buf_call(bufnr, function()
		local current = vim.fn.maparg(lhs, mode, false, true)
		if type(current) == "table" and current.buffer == 1 then
			mapping = current
		end
	end)
	return mapping
end

local function restore_buffer_keymap(bufnr, mode, lhs, mapping)
	if not mapping then
		pcall(vim.keymap.del, mode, lhs, { buffer = bufnr })
		return
	end

	local rhs = mapping.callback or mapping.rhs
	if not rhs then
		return
	end

	vim.keymap.set(mode, lhs, rhs, {
		buffer = bufnr,
		desc = mapping.desc,
		expr = mapping.expr == 1,
		noremap = mapping.noremap == 1,
		nowait = mapping.nowait == 1,
		script = mapping.script == 1,
		silent = mapping.silent == 1,
	})
end

local function suppress_hunk_echo(action)
	local original_echo = vim.api.nvim_echo
	vim.api.nvim_echo = function(chunks, history, opts)
		local message = chunks and chunks[1] and chunks[1][1] or ""
		if message:match("^Hunk %d+ of %d+$") or message:match("^First hunk %(") or message:match("^Last hunk %(") then
			return
		end

		return original_echo(chunks, history, opts)
	end

	local ok, err = pcall(action)
	vim.api.nvim_echo = original_echo
	vim.cmd.redrawstatus()
	if not ok then
		error(err)
	end
end

local function clear_buffer_keymaps(tabpage, bufnr)
	local tab_keymaps = overridden_buffer_keymaps[tabpage]
	local buffer_keymaps = tab_keymaps and tab_keymaps[bufnr] or nil
	if not buffer_keymaps then
		return
	end

	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		for _, override in pairs(buffer_keymaps) do
			restore_buffer_keymap(bufnr, override.mode, override.lhs, override.previous)
		end
	end

	tab_keymaps[bufnr] = nil
	if not next(tab_keymaps) then
		overridden_buffer_keymaps[tabpage] = nil
	end
end

local function collect_active_buffers(lifecycle, tabpage)
	local active_buffers = {}
	if not lifecycle then
		return active_buffers
	end

	local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
	for _, bufnr in ipairs({ original_bufnr, modified_bufnr }) do
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			active_buffers[bufnr] = true
		end
	end

	local explorer = lifecycle.get_explorer(tabpage)
	if explorer and explorer.bufnr and vim.api.nvim_buf_is_valid(explorer.bufnr) then
		active_buffers[explorer.bufnr] = true
	end

	if type(lifecycle.get_result) == "function" then
		local result_bufnr = lifecycle.get_result(tabpage)
		if result_bufnr and vim.api.nvim_buf_is_valid(result_bufnr) then
			active_buffers[result_bufnr] = true
		end
	end

	return active_buffers
end

local function remember_buffer(tabpage, session, bufnr)
	if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
		return
	end

	session.keymap_buffers = session.keymap_buffers or {}
	session.keymap_buffers[bufnr] = true

	tracked_keymap_buffers[tabpage] = tracked_keymap_buffers[tabpage] or {}
	tracked_keymap_buffers[tabpage][bufnr] = true
end

local function prune_inactive_buffers(tabpage, get_codediff_lifecycle)
	local tracked_buffers = tracked_keymap_buffers[tabpage]
	if not tracked_buffers then
		return
	end

	local lifecycle = get_codediff_lifecycle()
	local session = lifecycle and lifecycle.get_session(tabpage) or nil
	local active_buffers = session and collect_active_buffers(lifecycle, tabpage) or {}

	for bufnr, _ in pairs(tracked_buffers) do
		if not active_buffers[bufnr] then
			clear_buffer_keymaps(tabpage, bufnr)
			tracked_buffers[bufnr] = nil
		end
	end

	if not next(tracked_buffers) then
		tracked_keymap_buffers[tabpage] = nil
	end
end

local function wrap_tab_action(tabpage, get_codediff_lifecycle, action)
	return function()
		local lifecycle = get_codediff_lifecycle()
		local session = lifecycle and lifecycle.get_session(tabpage) or nil
		local current_buf = vim.api.nvim_get_current_buf()
		local active_buffers = session and collect_active_buffers(lifecycle, tabpage) or {}

		if not active_buffers[current_buf] then
			clear_buffer_keymaps(tabpage, current_buf)
			return
		end

		action()
	end
end

local function refresh_review_statusline(tabpage, get_codediff_lifecycle, deps)
	if deps.view.refresh_statusline then
		deps.view.refresh_statusline(get_codediff_lifecycle, tabpage)
	end
end

local function jump_unreviewed(tabpage, get_codediff_lifecycle, deps, direction)
	local lifecycle = get_codediff_lifecycle()
	local explorer = lifecycle and lifecycle.get_explorer(tabpage) or nil
	if not explorer then
		return
	end

	local file_data = deps.review.find_unreviewed(explorer, direction)
	if not file_data then
		return
	end

	deps.view.select_explorer_file(explorer, file_data)
	refresh_review_statusline(tabpage, get_codediff_lifecycle, deps)
	vim.schedule(function()
		deps.view.focus_diff_window(get_codediff_lifecycle, tabpage)
	end)
end

local function toggle_reviewed(tabpage, get_codediff_lifecycle, deps)
	local lifecycle = get_codediff_lifecycle()
	local explorer = lifecycle and lifecycle.get_explorer(tabpage) or nil
	if not explorer then
		return false
	end

	local reviewed = deps.review.toggle_current(explorer)
	refresh_review_statusline(tabpage, get_codediff_lifecycle, deps)
	return reviewed
end

local function review_and_advance(tabpage, get_codediff_lifecycle, deps)
	if toggle_reviewed(tabpage, get_codediff_lifecycle, deps) then
		jump_unreviewed(tabpage, get_codediff_lifecycle, deps, 1)
	end
end

local function clear_reviewed(tabpage, get_codediff_lifecycle, deps)
	local lifecycle = get_codediff_lifecycle()
	local explorer = lifecycle and lifecycle.get_explorer(tabpage) or nil
	if not explorer then
		return
	end

	deps.review.clear(explorer)
	refresh_review_statusline(tabpage, get_codediff_lifecycle, deps)
end

function M.install_buffer_update_hook(get_codediff_lifecycle, deps)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle or lifecycle._user_keymap_reconcile_installed then
		return
	end

	local original_update_buffers = lifecycle.update_buffers
	lifecycle.update_buffers = function(tabpage, original_bufnr, modified_bufnr)
		local ok = original_update_buffers(tabpage, original_bufnr, modified_bufnr)
		if ok then
			M.set_tab_keymaps(tabpage, get_codediff_lifecycle, deps)
		else
			prune_inactive_buffers(tabpage, get_codediff_lifecycle)
		end
		return ok
	end

	lifecycle._user_keymap_reconcile_installed = true
end

function M.set_tab_keymaps(tabpage, get_codediff_lifecycle, deps)
	local lifecycle = get_codediff_lifecycle()
	local session = lifecycle and lifecycle.get_session(tabpage) or nil
	if not lifecycle or not session then
		return
	end

	local function set_owned_buffer_keymap(bufnr, mode, lhs, rhs, desc)
		if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
			return
		end

		remember_buffer(tabpage, session, bufnr)

		overridden_buffer_keymaps[tabpage] = overridden_buffer_keymaps[tabpage] or {}
		local buffer_keymaps = overridden_buffer_keymaps[tabpage][bufnr] or {}
		overridden_buffer_keymaps[tabpage][bufnr] = buffer_keymaps
		local key = mode .. "\0" .. lhs
		local override = buffer_keymaps[key]
		local current = get_buffer_keymap(bufnr, mode, lhs)
		if not override then
			override = {
				mode = mode,
				lhs = lhs,
				previous = current,
			}
			buffer_keymaps[key] = override
		elseif not current or current.desc ~= override.desc then
			override.previous = current
		end

		override.desc = desc
		vim.keymap.set(mode, lhs, wrap_tab_action(tabpage, get_codediff_lifecycle, rhs), {
			buffer = bufnr,
			noremap = true,
			silent = true,
			nowait = true,
			desc = desc,
		})
	end

	local function set_buffer_keymap(bufnr, lhs, rhs, desc)
		set_owned_buffer_keymap(bufnr, "n", lhs, rhs, desc)
	end

	local function set_visual_buffer_keymap(bufnr, lhs, rhs, desc)
		set_owned_buffer_keymap(bufnr, "x", lhs, rhs, desc)
	end

	local function set_tab_keymap(lhs, rhs, desc)
		for bufnr, _ in pairs(collect_active_buffers(lifecycle, tabpage)) do
			set_buffer_keymap(bufnr, lhs, rhs, desc)
		end
	end

	for bufnr, _ in pairs(collect_active_buffers(lifecycle, tabpage)) do
		remember_buffer(tabpage, session, bufnr)
	end

	if session.mode == "explorer" then
		set_tab_keymap("ff", function()
			deps.actions.open_file_picker(get_codediff_lifecycle, tabpage)
		end, "Search files in codediff")

		set_tab_keymap("<leader>e", function()
			deps.view.toggle_explorer(get_codediff_lifecycle, tabpage)
		end, "Toggle codediff explorer")
	end

	set_tab_keymap("<C-q>", function()
		deps.view.close_view(get_codediff_lifecycle)
	end, "Close codediff view")

	set_tab_keymap("q", function()
		deps.view.close_view(get_codediff_lifecycle)
	end, "Close codediff view")

	set_tab_keymap("<leader>gZ", function()
		deps.view.toggle_result_zoom(get_codediff_lifecycle, tabpage)
	end, "Toggle merge result zoom")

	set_tab_keymap("<leader>gc", function()
		deps.actions.commit_staged(get_codediff_lifecycle, tabpage)
	end, "Commit staged changes")

	local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
	if session.mode == "explorer" then
		local navigation = adapter.navigation(nil, { "next_hunk", "prev_hunk" }, {
			notify = false,
		})

		for _, bufnr in ipairs({ original_bufnr, modified_bufnr }) do
			set_buffer_keymap(bufnr, "gd", function()
				lsp.jump_to_location(get_codediff_lifecycle, deps.view.close_view, "textDocument/definition")
			end, "Go to definition outside CodeDiff")

			set_buffer_keymap(bufnr, "gD", function()
				lsp.jump_to_location(get_codediff_lifecycle, deps.view.close_view, "textDocument/declaration")
			end, "Go to declaration outside CodeDiff")

			set_buffer_keymap(bufnr, "<CR>", function()
				deps.view.open_file_from_diff(get_codediff_lifecycle, tabpage)
			end, "Close codediff and open file at cursor")

			if navigation then
				set_buffer_keymap(bufnr, "<C-j>", function()
					suppress_hunk_echo(navigation.next_hunk)
				end, "Next codediff hunk")

				set_buffer_keymap(bufnr, "<C-k>", function()
					suppress_hunk_echo(navigation.prev_hunk)
				end, "Previous codediff hunk")
			end

			set_buffer_keymap(bufnr, "<leader>gz", function()
				deps.actions.stage_entry(get_codediff_lifecycle, tabpage)
			end, "Stage current entry")

			set_buffer_keymap(bufnr, "<leader>gu", function()
				deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
			end, "Unstage current entry")

			set_buffer_keymap(bufnr, "<leader>gx", function()
				deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
			end, "Discard current entry")

			set_buffer_keymap(bufnr, "r", function()
				review_and_advance(tabpage, get_codediff_lifecycle, deps)
			end, "Review current CodeDiff entry and advance")

			set_buffer_keymap(bufnr, "<leader>gR", function()
				clear_reviewed(tabpage, get_codediff_lifecycle, deps)
			end, "Clear CodeDiff reviewed marks")

			set_buffer_keymap(bufnr, "]r", function()
				jump_unreviewed(tabpage, get_codediff_lifecycle, deps, 1)
			end, "Next unreviewed CodeDiff file")

			set_buffer_keymap(bufnr, "[r", function()
				jump_unreviewed(tabpage, get_codediff_lifecycle, deps, -1)
			end, "Previous unreviewed CodeDiff file")
		end

		if type(lifecycle.get_result) == "function" then
			local result_bufnr = lifecycle.get_result(tabpage)
			set_buffer_keymap(result_bufnr, "<leader>gz", function()
				deps.actions.stage_entry(get_codediff_lifecycle, tabpage)
			end, "Stage resolved merge result")
		end
	end

	local explorer = lifecycle.get_explorer(tabpage)
	if explorer then
		explorer.hide_untracked = session.hide_untracked or false
	end
	if explorer and explorer.bufnr and vim.api.nvim_buf_is_valid(explorer.bufnr) then
		local navigation = adapter.navigation(nil, { "next_file", "prev_file" }, {
			notify = false,
		})

		set_buffer_keymap(explorer.bufnr, "<CR>", function()
			deps.view.open_explorer_entry(get_codediff_lifecycle, tabpage, explorer)
		end, "Open current codediff entry")

		if navigation then
			set_buffer_keymap(explorer.bufnr, "<Tab>", function()
				navigation.next_file()
			end, "Next codediff file")

			set_buffer_keymap(explorer.bufnr, "<S-Tab>", function()
				navigation.prev_file()
			end, "Previous codediff file")
		end

		set_buffer_keymap(explorer.bufnr, "<leader>gz", function()
			deps.actions.toggle_stage(get_codediff_lifecycle, tabpage)
		end, "Stage/unstage current entry")

		set_buffer_keymap(explorer.bufnr, "<leader>gu", function()
			deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
		end, "Unstage current entry")

		set_buffer_keymap(explorer.bufnr, "<leader>gx", function()
			deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
		end, "Discard current entry")

		set_buffer_keymap(explorer.bufnr, "r", function()
			toggle_reviewed(tabpage, get_codediff_lifecycle, deps)
		end, "Toggle CodeDiff reviewed")

		set_buffer_keymap(explorer.bufnr, "<leader>gR", function()
			clear_reviewed(tabpage, get_codediff_lifecycle, deps)
		end, "Clear CodeDiff reviewed marks")

		set_buffer_keymap(explorer.bufnr, "]r", function()
			jump_unreviewed(tabpage, get_codediff_lifecycle, deps, 1)
		end, "Next unreviewed CodeDiff file")

		set_buffer_keymap(explorer.bufnr, "[r", function()
			jump_unreviewed(tabpage, get_codediff_lifecycle, deps, -1)
		end, "Previous unreviewed CodeDiff file")

		set_buffer_keymap(explorer.bufnr, "s", function()
			deps.actions.stage_entry(get_codediff_lifecycle, tabpage)
		end, "Stage current entry")

		set_buffer_keymap(explorer.bufnr, "u", function()
			deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
		end, "Unstage current entry")

		set_buffer_keymap(explorer.bufnr, "x", function()
			deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
		end, "Discard current entry")

		set_visual_buffer_keymap(explorer.bufnr, "r", function()
			visual.toggle_reviewed(get_codediff_lifecycle, tabpage, deps)
		end, "Toggle selected CodeDiff reviewed")

		set_visual_buffer_keymap(explorer.bufnr, "s", function()
			visual.stage(get_codediff_lifecycle, tabpage, deps)
		end, "Stage selected CodeDiff entries")

		set_visual_buffer_keymap(explorer.bufnr, "u", function()
			visual.unstage(get_codediff_lifecycle, tabpage, deps)
		end, "Unstage selected CodeDiff entries")

		set_visual_buffer_keymap(explorer.bufnr, "<leader>gz", function()
			visual.stage(get_codediff_lifecycle, tabpage, deps)
		end, "Stage selected CodeDiff entries")

		set_visual_buffer_keymap(explorer.bufnr, "<leader>gu", function()
			visual.unstage(get_codediff_lifecycle, tabpage, deps)
		end, "Unstage selected CodeDiff entries")
	end

	prune_inactive_buffers(tabpage, get_codediff_lifecycle)
end

-- Remove our custom mappings and any hidden preload buffers once the codediff tab is done.
function M.clear_tab_keymaps(tabpage, get_codediff_lifecycle)
	local lifecycle = get_codediff_lifecycle()
	local session = lifecycle and lifecycle.get_session(tabpage) or nil
	local buffers_to_clear = {}

	if session and session.keymap_buffers then
		for bufnr, _ in pairs(session.keymap_buffers) do
			buffers_to_clear[bufnr] = true
		end
	end

	if tracked_keymap_buffers[tabpage] then
		for bufnr, _ in pairs(tracked_keymap_buffers[tabpage]) do
			buffers_to_clear[bufnr] = true
		end
	end

	for bufnr, _ in pairs(buffers_to_clear) do
		clear_buffer_keymaps(tabpage, bufnr)
	end

	tracked_keymap_buffers[tabpage] = nil
end

return M

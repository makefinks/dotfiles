local M = {}

local helpers = require("plugins.git.codediff.helpers")

local custom_codediff_keymaps =
	{ "<CR>", "<Tab>", "<S-Tab>", "<C-q>", "ff", "<leader>e", "<leader>gs", "<leader>gu", "<leader>gx", "s", "u", "x" }
local tracked_keymap_buffers = {}

local function clear_buffer_keymaps(bufnr)
	if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
		return
	end

	for _, lhs in ipairs(custom_codediff_keymaps) do
		pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
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
			clear_buffer_keymaps(bufnr)
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
			clear_buffer_keymaps(current_buf)
			return
		end

		action()
	end
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

	local function set_buffer_keymap(bufnr, lhs, rhs, desc)
		if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
			return
		end

		remember_buffer(tabpage, session, bufnr)

		vim.keymap.set("n", lhs, wrap_tab_action(tabpage, get_codediff_lifecycle, rhs), {
			buffer = bufnr,
			noremap = true,
			silent = true,
			nowait = true,
			desc = desc,
		})
	end

	for bufnr, _ in pairs(collect_active_buffers(lifecycle, tabpage)) do
		remember_buffer(tabpage, session, bufnr)
	end

	if session.mode == "explorer" then
		lifecycle.set_tab_keymap(
			tabpage,
			"n",
			"ff",
			wrap_tab_action(tabpage, get_codediff_lifecycle, function()
				deps.actions.open_file_picker(get_codediff_lifecycle, tabpage)
			end),
			{ desc = "Search files in codediff" }
		)

		lifecycle.set_tab_keymap(
			tabpage,
			"n",
			"<leader>e",
			wrap_tab_action(tabpage, get_codediff_lifecycle, function()
				deps.view.toggle_explorer(get_codediff_lifecycle, tabpage)
			end),
			{ desc = "Toggle codediff explorer" }
		)
	end

	lifecycle.set_tab_keymap(
		tabpage,
		"n",
		"<C-q>",
		wrap_tab_action(tabpage, get_codediff_lifecycle, function()
			deps.view.close_view(get_codediff_lifecycle)
		end),
		{ desc = "Close codediff view" }
	)

	local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
	if session.mode == "explorer" then
		for _, bufnr in ipairs({ original_bufnr, modified_bufnr }) do
			set_buffer_keymap(bufnr, "<CR>", function()
				deps.view.open_file_from_diff(get_codediff_lifecycle, tabpage)
			end, "Close codediff and open file at cursor")

			set_buffer_keymap(bufnr, "<leader>gs", function()
				deps.actions.stage_entry(get_codediff_lifecycle, tabpage)
			end, "Stage current entry")

			set_buffer_keymap(bufnr, "<leader>gu", function()
				deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
			end, "Unstage current entry")

			set_buffer_keymap(bufnr, "<leader>gx", function()
				deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
			end, "Discard current entry")
		end
	end

	local explorer = lifecycle.get_explorer(tabpage)
	if explorer then
		explorer.hide_untracked = session.hide_untracked or false
	end
	if explorer and explorer.bufnr and vim.api.nvim_buf_is_valid(explorer.bufnr) then
		local navigation = helpers.require_module("codediff.ui.view.navigation", nil, {
			notify = false,
			functions = { "next_file", "prev_file" },
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

		set_buffer_keymap(explorer.bufnr, "<leader>gs", function()
			deps.actions.toggle_stage(get_codediff_lifecycle, tabpage)
		end, "Stage/unstage current entry")

		set_buffer_keymap(explorer.bufnr, "<leader>gu", function()
			deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
		end, "Unstage current entry")

		set_buffer_keymap(explorer.bufnr, "<leader>gx", function()
			deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
		end, "Discard current entry")

		set_buffer_keymap(explorer.bufnr, "s", function()
			deps.actions.stage_entry(get_codediff_lifecycle, tabpage)
		end, "Stage current entry")

		set_buffer_keymap(explorer.bufnr, "u", function()
			deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
		end, "Unstage current entry")

		set_buffer_keymap(explorer.bufnr, "x", function()
			deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
		end, "Discard current entry")
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
		clear_buffer_keymaps(bufnr)
	end

	tracked_keymap_buffers[tabpage] = nil
end

return M

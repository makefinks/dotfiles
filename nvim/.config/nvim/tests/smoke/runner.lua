local M = {}

local errors = {}
local cwd = vim.fn.getcwd()
local fixtures_dir = cwd .. "/tests/fixtures"
local picker_fixtures_dir = fixtures_dir .. "/picker"

local function level_name(level)
	for name, value in pairs(vim.log.levels) do
		if value == level then
			return name
		end
	end
	return tostring(level)
end

local function push_error(message)
	errors[#errors + 1] = message
end

local function wait_for_callbacks()
	vim.wait(300, function()
		return false
	end, 25)
end

local function check_vim_errmsg(context)
	if vim.v.errmsg ~= "" then
		push_error(context .. ": " .. vim.v.errmsg)
		vim.v.errmsg = ""
	end
end

local function run_step(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	wait_for_callbacks()

	if not ok then
		push_error(name .. ": " .. err)
	end

	check_vim_errmsg(name)
end

local function open_fixture(path)
	vim.cmd.edit(vim.fn.fnameescape(path))

	local filetype = vim.bo.filetype
	if filetype ~= "" then
		pcall(vim.treesitter.start, 0, filetype)
	end
end

local function assert_current_buffer(path, context)
	local current = vim.api.nvim_buf_get_name(0)
	if vim.fn.fnamemodify(current, ":p") ~= vim.fn.fnamemodify(path, ":p") then
		error(string.format("%s opened %s instead of %s", context, current, path))
	end
end

local function assert_cursor_line(line, context)
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	if current_line ~= line then
		error(string.format("%s landed on line %d instead of %d", context, current_line, line))
	end
end

local function wait_until(message, predicate, timeout)
	local ok = vim.wait(timeout or 4000, predicate, 50)
	if not ok then
		error(message)
	end
end

local configured_plugins = {}

local function ensure_plugin_loaded(plugin_dir, spec_module)
	if configured_plugins[plugin_dir] then
		return
	end

	local plugin_path = vim.fn.stdpath("data") .. "/lazy/" .. plugin_dir
	if vim.fn.isdirectory(plugin_path) ~= 1 then
		error("missing plugin directory: " .. plugin_path)
	end

	vim.opt.rtp:prepend(plugin_path)

	local spec = require(spec_module)
	local opts = type(spec.opts) == "function" and spec.opts() or (spec.opts or {})
	if spec.config then
		spec.config(nil, opts)
	end

	configured_plugins[plugin_dir] = true
end

local function open_with_snacks_picker()
	local target = picker_fixtures_dir .. "/snacks/target.txt"
	local picker_dir = picker_fixtures_dir .. "/snacks"
	ensure_plugin_loaded("snacks.nvim", "plugins.packs.snacks")
	local snacks = require("snacks")
	local picker_mod = require("snacks.picker.core.picker")
	local actions = require("snacks.picker.actions")

	snacks.picker.files({ cwd = picker_dir, hidden = true, ignored = true })

	local picker
	wait_until("snacks picker did not start", function()
		picker = picker_mod.get({ source = "files" })[1]
		return picker ~= nil
	end)

	wait_until("snacks picker did not produce a selectable item", function()
		return picker:current({ resolve = true }) ~= nil
	end)

	actions.jump(picker, nil, { cmd = "edit" })
	wait_until("snacks picker did not open target buffer", function()
		return vim.api.nvim_buf_get_name(0) ~= ""
	end)
	assert_current_buffer(target, "snacks picker")
end

local function open_with_fff_picker()
	local target = picker_fixtures_dir .. "/fff/target.txt"
	local picker_dir = picker_fixtures_dir .. "/fff"
	ensure_plugin_loaded("fff.nvim", "plugins.navigation.fff")
	local fff = require("fff")
	local picker_ui = require("fff.picker_ui")

	fff.find_files({ cwd = picker_dir })

	wait_until("fff picker did not start", function()
		return picker_ui.state.active
	end)

	wait_until("fff picker did not produce a selectable item", function()
		return #picker_ui.state.filtered_items > 0
	end, 8000)

	picker_ui.select("edit")
	wait_until("fff picker did not open target buffer", function()
		return not picker_ui.state.active and vim.api.nvim_buf_get_name(0) ~= ""
	end)
	assert_current_buffer(target, "fff picker")
end

local function open_with_snacks_grep()
	local target = picker_fixtures_dir .. "/grep/match.txt"
	local picker_dir = picker_fixtures_dir .. "/grep"
	ensure_plugin_loaded("snacks.nvim", "plugins.packs.snacks")
	local snacks = require("snacks")
	local actions = require("snacks.picker.actions")

	local picker = snacks.picker.grep({
		cwd = picker_dir,
		hidden = true,
		ignored = true,
		search = "needle",
	})

	wait_until("snacks grep did not produce a selectable item", function()
		return picker and picker.list and picker.list:current() ~= nil
	end, 8000)

	actions.jump(picker, nil, { cmd = "edit" })
	wait_until("snacks grep did not open target buffer", function()
		return vim.api.nvim_buf_get_name(0) ~= ""
	end)
	assert_current_buffer(target, "snacks grep")
	assert_cursor_line(1, "snacks grep")
end

local function open_with_fff_grep()
	local target = picker_fixtures_dir .. "/grep/match.txt"
	local picker_dir = picker_fixtures_dir .. "/grep"
	ensure_plugin_loaded("fff.nvim", "plugins.navigation.fff")
	local fff = require("fff")
	local picker_ui = require("fff.picker_ui")

	fff.live_grep({ cwd = picker_dir, query = "needle" })

	wait_until("fff grep did not produce a selectable item", function()
		return picker_ui.state.active and #picker_ui.state.filtered_items > 0
	end, 8000)

	picker_ui.select("edit")
	wait_until("fff grep did not open target buffer", function()
		return not picker_ui.state.active and vim.api.nvim_buf_get_name(0) ~= ""
	end)
	assert_current_buffer(target, "fff grep")
	assert_cursor_line(1, "fff grep")
end

local function verify_ty_lsp_attach()
	local project_root = fixtures_dir .. "/ty_project"
	local target = project_root .. "/main.py"
	local ty_cmd = vim.fn.stdpath("data") .. "/mason/bin/ty"
	if vim.fn.executable(ty_cmd) ~= 1 then
		error("missing Mason ty binary: " .. ty_cmd)
	end

	local spec = require("plugins.lsp.astrolsp")
	local config = vim.deepcopy(spec.opts.config.ty)
	config.cmd = { ty_cmd, "server" }
	config.root_markers = nil
	open_fixture(target)

	local root_dir
	config.root_dir(0, function(resolved)
		root_dir = resolved
	end)
	if root_dir ~= project_root then
		error(string.format("ty LSP resolved root_dir %s instead of %s", tostring(root_dir), project_root))
	end

	config.root_dir = root_dir
	config.name = "ty"
	config.workspace_required = false
	local client_id = vim.lsp.start(config)
	if not client_id then
		error("vim.lsp.start did not return a ty client id")
	end

	local client
	wait_until("ty LSP did not attach to Python fixture", function()
		for _, attached in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
			if attached.name == "ty" then
				client = attached
				return true
			end
		end
		return false
	end, 8000)

	local client_root_dir = client and client.config and client.config.root_dir or nil
	if client_root_dir ~= project_root then
		error(string.format("ty LSP root_dir was %s instead of %s", tostring(client_root_dir), project_root))
	end
end

local function install_error_hooks()
	local original_notify = vim.notify
	vim.notify = function(message, level, opts)
		if (level or vim.log.levels.INFO) >= vim.log.levels.WARN then
			push_error(string.format("notify[%s]: %s", level_name(level), tostring(message)))
		end
		return original_notify(message, level, opts)
	end

	local original_schedule = vim.schedule
	vim.schedule = function(callback)
		return original_schedule(function()
			local ok, err = xpcall(callback, debug.traceback)
			if not ok then
				push_error("scheduled callback: " .. err)
			end
		end)
	end
end

function M.run()
	install_error_hooks()

	run_step("startup settle", function()
		check_vim_errmsg("startup")
	end)

	for _, fixture in ipairs({
		"plugin_spec.lua",
		"ghostty_progress.lua",
		"config_flow.vim",
		"render_markdown.md",
		"ty_project/main.py",
	}) do
		local path = fixtures_dir .. "/" .. fixture
		run_step("open " .. fixture, function()
			open_fixture(path)
		end)
	end

	run_step("snacks picker open", open_with_snacks_picker)
	run_step("fff picker open", open_with_fff_picker)
	run_step("snacks grep open", open_with_snacks_grep)
	run_step("fff grep open", open_with_fff_grep)
	run_step("ty lsp attach", verify_ty_lsp_attach)

	if #errors > 0 then
		error(table.concat(errors, "\n"))
	end

	print("smoke tests passed")
end

return M

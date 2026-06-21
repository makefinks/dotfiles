local get_codediff_lifecycle

local adapter = require("user.codediff.adapter")

local M = {}

local function get_codediff_modules()
	return {
		actions = require("user.codediff.actions"),
		adapter = adapter,
		filters = require("user.codediff.filters"),
		helpers = require("user.codediff.helpers"),
		keymaps = require("user.codediff.keymaps"),
		review = require("user.codediff.review"),
		view = require("user.codediff.view"),
	}
end

function M.open_pr_diff_against_branch()
	M.close_all_views()
	local modules = get_codediff_modules()

	local function open_filtered_command(command)
		local git = modules.adapter.git(nil, { "get_status", "get_diff_revision", "get_diff_revisions" }, {
			notify = false,
		})

		if not git then
			vim.cmd(command)
			return
		end

		local original_get_status = git.get_status
		local original_get_diff_revision = git.get_diff_revision
		local original_get_diff_revisions = git.get_diff_revisions
		local restored = false
		local group = vim.api.nvim_create_augroup("user_codediff_filtered_command", { clear = true })

		local function restore_git()
			if restored then
				return
			end

			git.get_status = original_get_status
			git.get_diff_revision = original_get_diff_revision
			git.get_diff_revisions = original_get_diff_revisions
			restored = true
		end

		git.get_status = function(git_root, callback)
			return original_get_status(git_root, function(err, status_result)
				callback(err, modules.filters.untracked_status_result(status_result))
			end)
		end

		git.get_diff_revision = function(revision, git_root, callback)
			return original_get_diff_revision(revision, git_root, function(err, status_result)
				callback(err, modules.filters.untracked_status_result(status_result))
			end)
		end

		git.get_diff_revisions = function(rev1, rev2, git_root, callback)
			return original_get_diff_revisions(rev1, rev2, git_root, function(err, status_result)
				callback(err, modules.filters.untracked_status_result(status_result))
			end)
		end

		vim.api.nvim_create_autocmd("User", {
			group = group,
			pattern = "CodeDiffOpen",
			once = true,
			callback = function(args)
				restore_git()
				local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
				modules.view.set_explorer_options(get_codediff_lifecycle, tabpage, { hide_untracked = true })
			end,
		})

		vim.defer_fn(restore_git, 10000)
		vim.cmd(command)
	end

	vim.ui.select({ "PR diff", "Branch vs working tree" }, { prompt = "Compare mode:" }, function(mode)
		if not mode then
			return
		end

		modules.helpers.with_branch(function(branch)
			local escaped_branch = vim.fn.fnameescape(branch)
			if mode == "PR diff" then
				open_filtered_command("CodeDiff " .. escaped_branch .. "...HEAD")
				return
			end

			open_filtered_command("CodeDiff " .. escaped_branch)
		end)
	end)
end

-- Safely access the active codediff lifecycle module.
get_codediff_lifecycle = function()
	return adapter.lifecycle()
end

function M.current_file_diff()
	M.close_all_views()
	local modules = get_codediff_modules()
	local context = modules.helpers.get_current_repo_file_info()
	if not context then
		return
	end

	modules.view.open_status_explorer(
		context.repo,
		context.rel,
		{ hide_untracked = true, focus_diff = true },
		get_codediff_lifecycle
	)
end

function M.project_diff(opts)
	M.close_all_views()
	opts = opts or {}
	local modules = get_codediff_modules()
	local repo = modules.helpers.get_cwd_repo()
	if not repo then
		return
	end

	modules.view.open_status_explorer(
		repo,
		nil,
		{ hide_untracked = opts.hide_untracked ~= false },
		get_codediff_lifecycle
	)
end

function M.close_view()
	get_codediff_modules().view.close_view(get_codediff_lifecycle)
end

function M.close_all_views()
	get_codediff_modules().view.close_all_views(get_codediff_lifecycle)
end

function M.resume_last_session()
	M.close_all_views()
	get_codediff_modules().view.resume_last_session(get_codediff_lifecycle)
end

function M.file_in_branch()
	M.close_all_views()
	local modules = get_codediff_modules()
	local context = modules.helpers.get_current_repo_file_info()
	if not context then
		return
	end

	vim.ui.select(
		{ "Diff view", "Open branch file", "Open branch file (split)" },
		{ prompt = "View mode:" },
		function(mode)
			if not mode then
				return
			end

			modules.helpers.with_branch(function(branch)
				if mode == "Diff view" then
					vim.cmd("CodeDiff file " .. vim.fn.fnameescape(branch))
					return
				end

				local split_mode = mode == "Open branch file (split)"
				modules.helpers.open_branch_preview(context.repo, context.rel, context.filetype, branch, split_mode)
			end)
		end
	)
end

function M.setup()
	local modules = get_codediff_modules()
	local conflict_labels = require("user.codediff.conflict_labels")
	local lsp = require("user.codediff.lsp")
	local keymap_deps = {
		actions = modules.actions,
		review = modules.review,
		view = modules.view,
	}

	-- This is intentionally a review workflow layer over CodeDiff internals: keep adapter.lua
	-- as the compatibility boundary for upstream API changes.
	modules.view.install_refresh_filter()
	modules.keymaps.install_buffer_update_hook(get_codediff_lifecycle, keymap_deps)

	local codediff_group = vim.api.nvim_create_augroup("user_codediff", { clear = true })
	conflict_labels.install(codediff_group)
	lsp.install_autocmds(codediff_group)

	vim.api.nvim_create_autocmd("User", {
		group = codediff_group,
		pattern = "CodeDiffOpen",
		callback = function(args)
			local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
			modules.view.ensure_explorer_window_state(get_codediff_lifecycle, tabpage)
			modules.keymaps.set_tab_keymaps(tabpage, get_codediff_lifecycle, keymap_deps)
		end,
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		group = codediff_group,
		callback = function()
			local tabpage = vim.api.nvim_get_current_tabpage()
			vim.schedule(function()
				if vim.api.nvim_tabpage_is_valid(tabpage) then
					modules.view.ensure_explorer_window_state(get_codediff_lifecycle, tabpage)
					modules.keymaps.set_tab_keymaps(tabpage, get_codediff_lifecycle, keymap_deps)
				end
			end)
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = codediff_group,
		pattern = "CodeDiffClose",
		callback = function(args)
			local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
			modules.view.save_resume_snapshot(get_codediff_lifecycle, tabpage)
			modules.view.clear_statusline_state(tabpage)
			modules.keymaps.clear_tab_keymaps(tabpage, get_codediff_lifecycle)
		end,
	})

	require("codediff").setup({
		diff = {
			layout = "side-by-side",
			cycle_next_hunk = false,
			-- Stop at the first/last file instead of wrapping back around.
			cycle_next_file = false,
		},
		explorer = {
			width = 60,
		},
		keymaps = {
			view = {
				quit = false,
				toggle_explorer = false,
				focus_explorer = false,
				next_hunk = false,
				prev_hunk = false,
				next_file = "<Tab>",
				prev_file = "<S-Tab>",
				diff_get = "do",
				diff_put = "dp",
				open_in_prev_tab = "gf",
				close_on_open_in_prev_tab = false,
				toggle_stage = false,
				stage_hunk = false,
				unstage_hunk = "<leader>hu",
				discard_hunk = false,
				hunk_textobject = "ih",
				align_move = "gm",
				toggle_layout = "t",
				show_help = "g?",
			},
			explorer = {
				select = "<CR>",
				hover = "K",
				refresh = "R",
				toggle_view_mode = "i",
				stage_all = "S",
				unstage_all = "U",
				restore = false,
				toggle_changes = "gu",
				toggle_staged = "gs",
				fold_open = "zo",
				fold_open_recursive = "zO",
				fold_close = "zc",
				fold_close_recursive = "zC",
				fold_toggle = "za",
				fold_toggle_recursive = "zA",
				fold_open_all = "zR",
				fold_close_all = "zM",
			},
		},
	})
end

return M

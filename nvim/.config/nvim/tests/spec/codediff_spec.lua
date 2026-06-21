local h = require("tests.helpers.codediff")

local original_cwd
local original_fn_input
local original_notify
local repo
local echo_capture

local function create_two_modified_files_repo()
	repo = h.create_temp_git_repo()
	repo.write_file("alpha.lua", { "return 'alpha'" })
	repo.write_file("beta.lua", { "return 'beta'" })
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "initial" })
	repo.write_file("alpha.lua", { "return 'alpha modified'" })
	repo.write_file("beta.lua", { "return 'beta modified'" })
	return repo
end

local function create_two_staged_files_repo()
	repo = create_two_modified_files_repo()
	repo.git_ok({ "add", "alpha.lua", "beta.lua" })
	return repo
end

local function create_staged_and_unstaged_repo()
	repo = h.create_temp_git_repo()
	repo.write_file("alpha.lua", { "return 'alpha'" })
	repo.write_file("beta.lua", { "return 'beta'" })
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "initial" })
	repo.write_file("alpha.lua", { "return 'alpha staged'" })
	repo.git_ok({ "add", "alpha.lua" })
	repo.write_file("beta.lua", { "return 'beta unstaged'" })
	return repo
end

local function create_staged_added_file_repo()
	repo = h.create_temp_git_repo()
	repo.write_file("tracked.lua", { "return 'tracked'" })
	repo.git_ok({ "add", "tracked.lua" })
	repo.git_ok({ "commit", "-m", "initial" })
	repo.write_file("new.lua", { "return 'new'" })
	repo.git_ok({ "add", "new.lua" })
	return repo
end

local function create_multiline_modified_files_repo()
	repo = h.create_temp_git_repo()
	repo.write_file("alpha.lua", {
		"local alpha = {",
		"  value = 'alpha',",
		"}",
		"",
		"return alpha",
	})
	repo.write_file("beta.lua", { "return 'beta'" })
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "initial" })
	repo.write_file("alpha.lua", {
		"local alpha = {",
		"  value = 'alpha modified',",
		"}",
		"",
		"return alpha",
	})
	repo.write_file("beta.lua", { "return 'beta modified'" })
	return repo
end

local function create_two_revision_repo()
	repo = h.create_temp_git_repo()
	repo.write_file("alpha.lua", {
		"local alpha = {",
		"  value = 'alpha',",
		"}",
		"",
		"return alpha",
	})
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "initial" })
	local base_revision = vim.trim(repo.git_ok({ "rev-parse", "HEAD" }))

	repo.write_file("alpha.lua", {
		"local alpha = {",
		"  value = 'alpha changed on branch',",
		"}",
		"",
		"return alpha",
	})
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "change alpha" })
	local head_revision = vim.trim(repo.git_ok({ "rev-parse", "HEAD" }))

	return repo, base_revision, head_revision
end

local function create_modified_and_untracked_repo()
	repo = h.create_temp_git_repo()
	repo.write_file("tracked.lua", { "return 'tracked'" })
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "initial" })
	repo.write_file("tracked.lua", { "return 'tracked modified'" })
	repo.write_file("scratch.md", { "scratch" })
	return repo
end

local function create_pr_diff_repo_with_dirty_worktree()
	repo = h.create_temp_git_repo()
	repo.write_file("tracked.lua", { "return 'tracked'" })
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "initial" })
	repo.git_ok({ "checkout", "-b", "feature" })
	repo.write_file("feature.lua", { "return 'feature'" })
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "feature" })
	repo.write_file("tracked.lua", { "return 'dirty worktree'" })
	return repo
end

local function create_merge_conflict_repo()
	repo = h.create_temp_git_repo()
	repo.write_file("app.ts", { "export const value = 'base'" })
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "base" })
	repo.git_ok({ "checkout", "-b", "feature" })
	repo.write_file("app.ts", { "export const value = 'incoming'" })
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "incoming" })
	repo.git_ok({ "checkout", "main" })
	repo.write_file("app.ts", { "export const value = 'current'" })
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "current" })
	repo.git({ "merge", "feature" })
	return repo
end

local function open_conflict_file()
	repo = create_merge_conflict_repo()
	local tabpage, _, explorer = h.open_status_explorer(repo, "app.ts", { hide_untracked = true })
	local lifecycle = h.get_codediff_lifecycle()

	h.wait_for(function()
		local session = lifecycle.get_session(tabpage)
		return explorer.current_file_path == "app.ts"
			and explorer.current_file_group == "conflicts"
			and session
			and session.result_bufnr
			and vim.api.nvim_buf_is_valid(session.result_bufnr)
			and session.result_win
			and vim.api.nvim_win_is_valid(session.result_win)
	end, 15000, "CodeDiff did not open the conflict file")

	return tabpage, lifecycle.get_session(tabpage), explorer
end

local function create_large_schema_repo()
	repo = h.create_temp_git_repo()
	local lines = {
		"{",
		string.format("%q: %q", "schema", string.rep("x", 520 * 1024)),
		"}",
	}

	repo.write_file("schema.json", lines)
	repo.git_ok({ "add", "." })
	repo.git_ok({ "commit", "-m", "initial" })
	table.insert(lines, 2, '"changed": true,')
	repo.write_file("schema.json", lines)
	return repo
end

local function with_branch_and_mode(branch, mode, callback)
	local helpers = require("user.codediff.helpers")
	local original_with_branch = helpers.with_branch
	local original_select = vim.ui.select

	helpers.with_branch = function(branch_callback)
		branch_callback(branch)
	end

	vim.ui.select = function(_, _, select_callback)
		select_callback(mode)
	end

	local ok, err = pcall(callback)
	helpers.with_branch = original_with_branch
	vim.ui.select = original_select

	if not ok then
		error(err)
	end
end

describe("local CodeDiff workflow", function()
	before_each(function()
		original_cwd = vim.fn.getcwd()
		require("user.codediff.resume").clear_persisted()
		h.reset_editor()
		echo_capture = h.capture_echoes()
	end)

	after_each(function()
		if original_notify then
			vim.notify = original_notify
			original_notify = nil
		end

		if original_fn_input then
			vim.fn.input = original_fn_input
			original_fn_input = nil
		end

		if echo_capture then
			echo_capture.restore()
			echo_capture = nil
		end

		vim.fn.chdir(original_cwd)
		h.reset_editor()
		require("user.codediff.resume").clear_persisted()
		vim.wait(200)

		if repo then
			repo.cleanup()
			repo = nil
		end
	end)

	it("stages from hidden diff buffers and reopens with refreshed explorer state", function()
		local actions = require("user.codediff.actions")

		repo = create_two_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		h.set_explorer_hidden(tabpage, true)
		h.focus_modified_window(tabpage)
		actions.stage_entry(h.get_codediff_lifecycle, tabpage)

		h.wait_for(function()
			local status_result = explorer.status_result
			return explorer.current_file_path == "beta.lua"
				and explorer.current_file_group == "unstaged"
				and h.status_has_path(status_result, "staged", "alpha.lua")
				and not h.status_has_path(status_result, "unstaged", "alpha.lua")
				and h.status_has_path(status_result, "unstaged", "beta.lua")
		end, 15000, "Hidden stage_entry did not refresh CodeDiff state")

		h.set_explorer_hidden(tabpage, false)

		assert.is_not_nil(h.find_tree_entry(explorer, "alpha.lua", "staged"))
		assert.is_nil(h.find_tree_entry(explorer, "alpha.lua", "unstaged"))
		assert.is_not_nil(h.find_tree_entry(explorer, "beta.lua", "unstaged"))
	end)

	it("disables LSP for large diff buffers", function()
		repo = create_large_schema_repo()
		local tabpage = h.open_status_explorer(repo, "schema.json", { hide_untracked = true })
		local lifecycle = h.get_codediff_lifecycle()

		h.wait_for(function()
			local session = lifecycle.get_session(tabpage)
			return session and vim.b[session.modified_bufnr].codediff_lsp_disabled == true
		end, 10000, "Large CodeDiff buffer did not disable LSP")

		local session = lifecycle.get_session(tabpage)
		assert.is_true(vim.b[session.modified_bufnr].codediff_lsp_disabled)
		assert.are.equal("", vim.bo[session.modified_bufnr].filetype)
		assert.are.equal(0, #vim.lsp.get_clients({ bufnr = session.modified_bufnr }))
	end)

	it("unstages from hidden diff buffers and reopens with refreshed explorer state", function()
		local actions = require("user.codediff.actions")

		repo = create_two_staged_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "staged"
		end, 10000, "CodeDiff did not select alpha.lua in the staged group")

		h.set_explorer_hidden(tabpage, true)
		h.focus_modified_window(tabpage)
		actions.unstage_entry(h.get_codediff_lifecycle, tabpage)

		h.wait_for(function()
			local status_result = explorer.status_result
			return explorer.current_file_path == "beta.lua"
				and explorer.current_file_group == "staged"
				and h.status_has_path(status_result, "unstaged", "alpha.lua")
				and not h.status_has_path(status_result, "staged", "alpha.lua")
				and h.status_has_path(status_result, "staged", "beta.lua")
		end, 15000, "Hidden unstage_entry did not refresh CodeDiff state")

		h.set_explorer_hidden(tabpage, false)

		assert.is_not_nil(h.find_tree_entry(explorer, "alpha.lua", "unstaged"))
		assert.is_nil(h.find_tree_entry(explorer, "alpha.lua", "staged"))
		assert.is_not_nil(h.find_tree_entry(explorer, "beta.lua", "staged"))
	end)

	it("stages visually selected explorer files", function()
		repo = create_two_modified_files_repo()
		local _, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua"
				and h.find_tree_entry(explorer, "alpha.lua", "unstaged")
				and h.find_tree_entry(explorer, "beta.lua", "unstaged")
		end, 10000, "CodeDiff did not open both unstaged files")

		local alpha_line = h.find_tree_line(explorer, "alpha.lua", "unstaged")
		local beta_line = h.find_tree_line(explorer, "beta.lua", "unstaged")
		assert.is_not_nil(alpha_line)
		assert.is_not_nil(beta_line)

		h.invoke_visual_keymap(explorer, alpha_line, beta_line, "s")

		h.wait_for(function()
			local status_result = explorer.status_result
			return h.status_has_path(status_result, "staged", "alpha.lua")
				and h.status_has_path(status_result, "staged", "beta.lua")
				and not h.status_has_path(status_result, "unstaged", "alpha.lua")
				and not h.status_has_path(status_result, "unstaged", "beta.lua")
		end, 15000, "Visual CodeDiff stage did not stage selected files")
	end)

	it("unstages visually selected explorer files", function()
		repo = create_two_staged_files_repo()
		local _, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua"
				and h.find_tree_entry(explorer, "alpha.lua", "staged")
				and h.find_tree_entry(explorer, "beta.lua", "staged")
		end, 10000, "CodeDiff did not open both staged files")

		local alpha_line = h.find_tree_line(explorer, "alpha.lua", "staged")
		local beta_line = h.find_tree_line(explorer, "beta.lua", "staged")
		assert.is_not_nil(alpha_line)
		assert.is_not_nil(beta_line)

		h.invoke_visual_keymap(explorer, alpha_line, beta_line, "u")

		h.wait_for(function()
			local status_result = explorer.status_result
			return h.status_has_path(status_result, "unstaged", "alpha.lua")
				and h.status_has_path(status_result, "unstaged", "beta.lua")
				and not h.status_has_path(status_result, "staged", "alpha.lua")
				and not h.status_has_path(status_result, "staged", "beta.lua")
		end, 15000, "Visual CodeDiff unstage did not unstage selected files")
	end)

	it("commits staged files from the CodeDiff mapping without staging unstaged files", function()
		repo = create_staged_and_unstaged_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return h.status_has_path(explorer.status_result, "staged", "alpha.lua")
				and h.status_has_path(explorer.status_result, "unstaged", "beta.lua")
		end, 10000, "CodeDiff did not open staged and unstaged files")

		original_fn_input = vim.fn.input
		vim.fn.input = function()
			return "commit staged alpha"
		end

		local modified_bufnr
		h.wait_for(function()
			modified_bufnr = h.focus_modified_window(tabpage)
			return h.buffer_has_keymap(modified_bufnr, "<leader>gc")
		end, 10000, "CodeDiff commit mapping was not ready")

		vim.api.nvim_buf_call(modified_bufnr, function()
			vim.fn.maparg("<leader>gc", "n", false, true).callback()
		end)

		h.wait_for(function()
			return vim.trim(repo.git_ok({ "log", "-1", "--pretty=%s" })) == "commit staged alpha"
		end, 15000, "CodeDiff commit mapping did not create a commit")

		h.wait_for(function()
			local status_result = explorer.status_result
			return not h.status_has_path(status_result, "staged", "alpha.lua")
				and not h.status_has_path(status_result, "unstaged", "alpha.lua")
				and h.status_has_path(status_result, "unstaged", "beta.lua")
		end, 15000, "CodeDiff did not refresh after committing staged files")

		assert.matches("^ M beta%.lua", repo.git_ok({ "status", "--short" }))
	end)

	it("does not prompt for a commit message when nothing is staged", function()
		local actions = require("user.codediff.actions")

		repo = create_two_modified_files_repo()
		local tabpage = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })
		local head_before = vim.trim(repo.git_ok({ "rev-parse", "HEAD" }))
		local prompted = false
		local warned = false

		original_fn_input = vim.fn.input
		vim.fn.input = function()
			prompted = true
			return "should not commit"
		end

		original_notify = vim.notify
		vim.notify = function(message, level, opts)
			if message == "No staged changes to commit" then
				warned = true
			end

			return original_notify(message, level, opts)
		end

		actions.commit_staged(h.get_codediff_lifecycle, tabpage)

		h.wait_for(function()
			return warned
		end, 10000, "CodeDiff did not warn about an empty index")

		assert.is_false(prompted)
		assert.are.equal(head_before, vim.trim(repo.git_ok({ "rev-parse", "HEAD" })))
	end)

	it("rebinds diff-buffer mappings after staging advances to the next file", function()
		local actions = require("user.codediff.actions")

		repo = create_two_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		local first_modified_bufnr
		h.wait_for(function()
			first_modified_bufnr = h.focus_modified_window(tabpage)
			return h.buffer_has_keymap(first_modified_bufnr, "<leader>gz")
				and h.buffer_has_keymap(first_modified_bufnr, "ff")
		end, 10000, "CodeDiff diff-buffer mappings were not ready")

		actions.stage_entry(h.get_codediff_lifecycle, tabpage)

		local second_modified_bufnr
		h.wait_for(function()
			local _, bufnr = h.get_codediff_lifecycle().get_buffers(tabpage)
			second_modified_bufnr = bufnr
			return explorer.current_file_path == "beta.lua"
				and explorer.current_file_group == "unstaged"
				and second_modified_bufnr
				and vim.api.nvim_buf_is_valid(second_modified_bufnr)
				and second_modified_bufnr ~= first_modified_bufnr
				and h.buffer_has_keymap(second_modified_bufnr, "<leader>gz")
				and h.buffer_has_keymap(second_modified_bufnr, "ff")
		end, 15000, "Staging did not advance to beta.lua")

		if vim.api.nvim_buf_is_valid(first_modified_bufnr) then
			assert.is_false(h.buffer_has_keymap(first_modified_bufnr, "<leader>gz"))
			assert.is_false(h.buffer_has_keymap(first_modified_bufnr, "ff"))
		end
	end)

	it("does not stage unresolved merge conflicts from diff buffers", function()
		local actions = require("user.codediff.actions")

		local tabpage, session = open_conflict_file()
		vim.api.nvim_set_current_win(session.modified_win)

		actions.stage_entry(h.get_codediff_lifecycle, tabpage)

		local status = repo.git_ok({ "status", "--short" })
		assert.matches("UU app%.ts", status)
		assert.are.equal(session.result_win, vim.api.nvim_get_current_win())
	end)

	it("stages the saved merge result after conflicts are resolved", function()
		local actions = require("user.codediff.actions")

		local tabpage, session = open_conflict_file()
		vim.api.nvim_buf_set_lines(session.result_bufnr, 0, -1, false, { "export const value = 'merged'" })
		vim.api.nvim_set_current_win(session.result_win)

		actions.stage_entry(h.get_codediff_lifecycle, tabpage)

		h.wait_for(function()
			local status = repo.git_ok({ "status", "--short" })
			return status:match("M  app%.ts") and not status:match("UU app%.ts")
		end, 10000, "Resolved merge result was not staged")
	end)

	it("marks files reviewed and advances to the next unreviewed file from diff buffers", function()
		repo = create_two_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		local modified_bufnr
		h.wait_for(function()
			modified_bufnr = h.focus_modified_window(tabpage)
			return h.buffer_has_keymap(modified_bufnr, "r") and h.buffer_has_keymap(modified_bufnr, "]r")
		end, 10000, "CodeDiff review mappings were not ready")

		vim.api.nvim_buf_call(modified_bufnr, function()
			vim.fn.maparg("r", "n", false, true).callback()
		end)

		h.wait_for(function()
			local state = require("user.codediff.view").get_statusline_state(tabpage)
			return state
				and state.review_progress == "Reviewed 1/2"
				and explorer.current_file_path == "beta.lua"
				and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not mark alpha.lua reviewed and advance to beta.lua")
	end)

	it("clears reviewed marks", function()
		repo = create_two_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		local review = require("user.codediff.review")
		review.toggle_current(explorer)
		require("user.codediff.view").refresh_statusline(h.get_codediff_lifecycle, tabpage)

		h.wait_for(function()
			local state = require("user.codediff.view").get_statusline_state(tabpage)
			return state and state.review_progress == "Reviewed 1/2"
		end, 10000, "CodeDiff did not record a reviewed mark")

		review.clear(explorer)
		require("user.codediff.view").refresh_statusline(h.get_codediff_lifecycle, tabpage)

		h.wait_for(function()
			local state = require("user.codediff.view").get_statusline_state(tabpage)
			return state and state.review_progress == "Reviewed 0/2"
		end, 10000, "CodeDiff did not clear reviewed marks")
	end)

	it("marks the explorer cursor file reviewed instead of the selected diff file", function()
		repo = create_two_modified_files_repo()
		local _, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		local beta_line = h.find_tree_line(explorer, "beta.lua", "unstaged")
		assert.is_not_nil(beta_line)
		local alpha_line = h.find_tree_line(explorer, "alpha.lua", "unstaged")
		assert.is_not_nil(alpha_line)

		vim.api.nvim_set_current_buf(explorer.bufnr)
		vim.api.nvim_win_set_cursor(0, { beta_line, 0 })
		vim.fn.maparg("r", "n", false, true).callback()

		local review = require("user.codediff.review")
		assert.is_false(review.is_reviewed(explorer, { path = "alpha.lua", group = "unstaged" }))
		assert.is_true(review.is_reviewed(explorer, { path = "beta.lua", group = "unstaged" }))
		assert.is_false(h.line_has_review_mark(explorer, alpha_line))
		assert.is_true(h.line_has_review_mark(explorer, beta_line))

		explorer.tree:render()
		assert.is_false(h.line_has_review_mark(explorer, alpha_line))
		assert.is_true(h.line_has_review_mark(explorer, beta_line))
	end)

	it("keeps reviewed background off the selected explorer row", function()
		repo = create_two_modified_files_repo()
		local _, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua"
				and h.find_tree_entry(explorer, "alpha.lua", "unstaged")
				and h.find_tree_entry(explorer, "beta.lua", "unstaged")
		end, 10000, "CodeDiff did not open both unstaged files")

		local alpha_line = h.find_tree_line(explorer, "alpha.lua", "unstaged")
		local beta_line = h.find_tree_line(explorer, "beta.lua", "unstaged")
		assert.is_not_nil(alpha_line)
		assert.is_not_nil(beta_line)

		local review = require("user.codediff.review")
		review.toggle_files(explorer, {
			{ path = "alpha.lua", group = "unstaged" },
			{ path = "beta.lua", group = "unstaged" },
		})
		vim.api.nvim_set_current_win(explorer.winid)
		vim.api.nvim_win_set_cursor(explorer.winid, { beta_line, 0 })
		review.render(explorer)

		local namespace = review.get_namespace()
		local function has_review_background(line)
			local marks = vim.api.nvim_buf_get_extmarks(explorer.bufnr, namespace, 0, -1, { details = true })
			for _, mark in ipairs(marks) do
				local details = mark[4]
				if mark[2] == line - 1 and details and details.line_hl_group == "UserCodeDiffReviewed" then
					return true
				end
			end

			return false
		end

		assert.is_false(has_review_background(alpha_line))
		assert.is_true(has_review_background(beta_line))
	end)

	it("marks visually selected explorer files reviewed", function()
		repo = create_two_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua"
				and h.find_tree_entry(explorer, "alpha.lua", "unstaged")
				and h.find_tree_entry(explorer, "beta.lua", "unstaged")
		end, 10000, "CodeDiff did not open both unstaged files")

		local alpha_line = h.find_tree_line(explorer, "alpha.lua", "unstaged")
		local beta_line = h.find_tree_line(explorer, "beta.lua", "unstaged")
		assert.is_not_nil(alpha_line)
		assert.is_not_nil(beta_line)

		h.invoke_visual_keymap(explorer, alpha_line, beta_line, "r")

		local review = require("user.codediff.review")
		assert.is_true(review.is_reviewed(explorer, { path = "alpha.lua", group = "unstaged" }))
		assert.is_true(review.is_reviewed(explorer, { path = "beta.lua", group = "unstaged" }))
		assert.is_true(h.line_has_review_mark(explorer, alpha_line))
		assert.is_true(h.line_has_review_mark(explorer, beta_line))

		local state = require("user.codediff.view").get_statusline_state(tabpage)
		assert.equals("Reviewed 2/2", state and state.review_progress)
	end)

	it("closes codediff and opens the working tree file at the diff cursor", function()
		local view = require("user.codediff.view")

		repo = create_two_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		local modified_bufnr
		h.wait_for(function()
			modified_bufnr = h.focus_modified_window(tabpage)
			return modified_bufnr
				and vim.api.nvim_buf_is_valid(modified_bufnr)
				and h.buffer_has_keymap(modified_bufnr, "<CR>")
		end, 10000, "CodeDiff diff-buffer enter mapping was not ready")

		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		view.open_file_from_diff(h.get_codediff_lifecycle, tabpage)

		h.wait_for(function()
			return vim.api.nvim_buf_get_name(0) == repo.path("alpha.lua")
		end, 10000, "CodeDiff did not open the working tree file")

		assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
		assert.is_nil(h.get_codediff_lifecycle().get_session(tabpage))
	end)

	it("resumes the last codediff session at the saved diff cursor", function()
		local view = require("user.codediff.view")

		repo = create_multiline_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		local modified_bufnr
		h.wait_for(function()
			modified_bufnr = h.focus_modified_window(tabpage)
			return modified_bufnr
				and vim.api.nvim_buf_is_valid(modified_bufnr)
				and vim.api.nvim_buf_line_count(modified_bufnr) >= 2
				and h.buffer_has_keymap(modified_bufnr, "<CR>")
		end, 10000, "CodeDiff diff-buffer enter mapping was not ready")

		vim.api.nvim_win_set_cursor(0, { 2, 2 })
		view.open_file_from_diff(h.get_codediff_lifecycle, tabpage)

		h.wait_for(function()
			return vim.api.nvim_buf_get_name(0) == repo.path("alpha.lua")
		end, 10000, "CodeDiff did not open the working tree file")

		view.resume_last_session(h.get_codediff_lifecycle)

		local resumed_tabpage, resumed_session, resumed_explorer = h.wait_for_explorer_session({
			file_path = "alpha.lua",
			group = "unstaged",
		}, 15000, "CodeDiff did not reopen the saved session")

		h.wait_for(function()
			return resumed_session
				and resumed_session.modified_win
				and vim.api.nvim_win_is_valid(resumed_session.modified_win)
				and vim.api.nvim_get_current_win() == resumed_session.modified_win
				and vim.deep_equal(vim.api.nvim_win_get_cursor(resumed_session.modified_win), { 2, 2 })
		end, 15000, "CodeDiff did not restore the saved diff cursor")

		assert.is_not_nil(resumed_tabpage)
		assert.is_not_nil(resumed_explorer)
	end)

	it("resumes the last codediff session after closing the view", function()
		local view = require("user.codediff.view")
		local lifecycle = h.get_codediff_lifecycle()

		repo = create_multiline_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		local modified_bufnr
		h.wait_for(function()
			modified_bufnr = h.focus_modified_window(tabpage)
			return modified_bufnr
				and vim.api.nvim_buf_is_valid(modified_bufnr)
				and vim.api.nvim_buf_line_count(modified_bufnr) >= 2
		end, 10000, "CodeDiff modified buffer was not ready")

		vim.api.nvim_win_set_cursor(0, { 2, 2 })
		view.close_view(h.get_codediff_lifecycle)

		h.wait_for(function()
			return lifecycle.get_session(tabpage) == nil
		end, 10000, "CodeDiff did not close")

		view.resume_last_session(h.get_codediff_lifecycle)

		local _, resumed_session, resumed_explorer = h.wait_for_explorer_session({
			file_path = "alpha.lua",
			group = "unstaged",
		}, 15000, "CodeDiff did not reopen the closed session")

		h.wait_for(function()
			return resumed_session
				and resumed_session.modified_win
				and vim.api.nvim_win_is_valid(resumed_session.modified_win)
				and vim.api.nvim_get_current_win() == resumed_session.modified_win
				and vim.deep_equal(vim.api.nvim_win_get_cursor(resumed_session.modified_win), { 2, 2 })
		end, 15000, "CodeDiff did not restore the saved close cursor")

		assert.is_not_nil(resumed_explorer)
	end)

	it("resumes status explorers with staged and unstaged groups intact", function()
		local view = require("user.codediff.view")
		local lifecycle = h.get_codediff_lifecycle()

		repo = create_staged_and_unstaged_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "beta.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "beta.lua"
				and explorer.current_file_group == "unstaged"
				and h.find_tree_entry(explorer, "alpha.lua", "staged")
				and h.find_tree_entry(explorer, "beta.lua", "unstaged")
		end, 10000, "CodeDiff did not open the status explorer with both groups")

		view.close_view(h.get_codediff_lifecycle)

		h.wait_for(function()
			return lifecycle.get_session(tabpage) == nil
		end, 10000, "CodeDiff did not close")

		view.resume_last_session(h.get_codediff_lifecycle)

		local _, _, resumed_explorer = h.wait_for_explorer_session({
			file_path = "beta.lua",
			group = "unstaged",
		}, 15000, "CodeDiff did not resume the saved status explorer")

		h.wait_for(function()
			return h.find_tree_entry(resumed_explorer, "alpha.lua", "staged")
				and h.find_tree_entry(resumed_explorer, "beta.lua", "unstaged")
				and not h.find_tree_entry(resumed_explorer, "alpha.lua", "unstaged")
		end, 10000, "Resume did not preserve staged and unstaged status groups")
	end)

	it("resumes reviewed file marks from persisted state", function()
		local view = require("user.codediff.view")
		local lifecycle = h.get_codediff_lifecycle()
		local review = require("user.codediff.review")
		local resume = require("user.codediff.resume")

		repo = create_two_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		review.toggle_current(explorer)
		view.refresh_statusline(h.get_codediff_lifecycle, tabpage)

		h.wait_for(function()
			local state = view.get_statusline_state(tabpage)
			return state and state.review_progress == "Reviewed 1/2"
		end, 10000, "CodeDiff did not mark alpha.lua as reviewed")

		view.close_view(h.get_codediff_lifecycle)

		h.wait_for(function()
			return lifecycle.get_session(tabpage) == nil
		end, 10000, "CodeDiff did not close")

		resume.forget_memory()
		view.resume_last_session(h.get_codediff_lifecycle)

		local resumed_tabpage, _, resumed_explorer = h.wait_for_explorer_session({
			file_path = "alpha.lua",
			group = "unstaged",
		}, 15000, "CodeDiff did not resume the reviewed session")

		local alpha_line = h.find_tree_line(resumed_explorer, "alpha.lua", "unstaged")
		assert.is_not_nil(alpha_line)
		h.wait_for(function()
			return review.is_reviewed(resumed_explorer, { path = "alpha.lua", group = "unstaged" })
				and h.line_has_review_mark(resumed_explorer, alpha_line)
		end, 10000, "CodeDiff did not restore reviewed marks")

		h.wait_for(function()
			local state = view.get_statusline_state(resumed_tabpage)
			return state and state.review_progress == "Reviewed 1/2"
		end, 10000, "CodeDiff did not restore reviewed progress")
	end)

	it("resumes persisted state at the first available file when saved file is clean", function()
		local view = require("user.codediff.view")
		local lifecycle = h.get_codediff_lifecycle()
		local review = require("user.codediff.review")
		local resume = require("user.codediff.resume")

		repo = create_two_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		review.toggle_current(explorer)
		view.refresh_statusline(h.get_codediff_lifecycle, tabpage)
		view.close_view(h.get_codediff_lifecycle)

		h.wait_for(function()
			return lifecycle.get_session(tabpage) == nil
		end, 10000, "CodeDiff did not close")

		repo.git_ok({ "checkout", "--", "alpha.lua" })
		resume.forget_memory()
		view.resume_last_session(h.get_codediff_lifecycle)

		local resumed_tabpage, _, resumed_explorer = h.wait_for_explorer_session({
			file_path = "beta.lua",
			group = "unstaged",
		}, 15000, "CodeDiff did not resume at the remaining changed file")

		assert.is_false(review.is_reviewed(resumed_explorer, { path = "beta.lua", group = "unstaged" }))
		h.wait_for(function()
			local state = view.get_statusline_state(resumed_tabpage)
			return state and state.review_progress == "Reviewed 0/1"
		end, 10000, "CodeDiff counted stale reviewed marks")
	end)

	it("resumes revision explorer sessions with their original revisions", function()
		local view = require("user.codediff.view")
		local lifecycle = h.get_codediff_lifecycle()

		local base_revision
		local head_revision
		repo, base_revision, head_revision = create_two_revision_repo()
		vim.fn.chdir(repo.dir)
		vim.cmd("CodeDiff " .. base_revision .. " " .. head_revision)

		local tabpage, session = h.wait_for_explorer_session({
			file_path = "alpha.lua",
			original_revision = base_revision,
			modified_revision = head_revision,
		}, 15000, "CodeDiff revision explorer did not open alpha.lua")

		h.wait_for(function()
			return session.modified_win and vim.api.nvim_win_is_valid(session.modified_win)
		end, 10000, "CodeDiff revision modified window was not ready")

		vim.api.nvim_set_current_win(session.modified_win)
		vim.api.nvim_win_set_cursor(0, { 2, 2 })
		view.close_view(h.get_codediff_lifecycle)

		h.wait_for(function()
			return lifecycle.get_session(tabpage) == nil
		end, 10000, "CodeDiff revision explorer did not close")

		view.resume_last_session(h.get_codediff_lifecycle)

		local _, resumed_session, resumed_explorer = h.wait_for_explorer_session({
			file_path = "alpha.lua",
			original_revision = base_revision,
			modified_revision = head_revision,
		}, 15000, "CodeDiff did not resume the saved revision explorer")

		h.wait_for(function()
			return resumed_session
				and resumed_session.modified_win
				and vim.api.nvim_win_is_valid(resumed_session.modified_win)
				and vim.api.nvim_get_current_win() == resumed_session.modified_win
				and vim.deep_equal(vim.api.nvim_win_get_cursor(resumed_session.modified_win), { 2, 2 })
		end, 15000, "CodeDiff did not restore the revision diff cursor")

		assert.is_not_nil(resumed_explorer)
		assert.equals(base_revision, resumed_session.original_revision)
		assert.equals(head_revision, resumed_session.modified_revision)
	end)

	it("keeps untracked files hidden after resuming revision explorers", function()
		local view = require("user.codediff.view")
		local lifecycle = h.get_codediff_lifecycle()

		repo = create_modified_and_untracked_repo()
		local head_revision = vim.trim(repo.git_ok({ "rev-parse", "HEAD" }))
		vim.fn.chdir(repo.dir)
		vim.cmd("CodeDiff HEAD")

		local tabpage
		local session
		local explorer
		h.wait_for(function()
			for _, current_tabpage in ipairs(vim.api.nvim_list_tabpages()) do
				local current_session = lifecycle.get_session(current_tabpage)
				local current_explorer = lifecycle.get_explorer(current_tabpage)
				if
					current_session
					and current_explorer
					and current_explorer.base_revision == head_revision
					and current_explorer.target_revision == "WORKING"
				then
					tabpage = current_tabpage
					session = current_session
					explorer = current_explorer
					return true
				end
			end

			return false
		end, 15000, "Revision CodeDiff explorer did not open tracked.lua")

		view.set_explorer_options(h.get_codediff_lifecycle, tabpage, {
			hide_untracked = true,
		})
		local tracked_node = h.find_tree_entry(explorer, "tracked.lua", "unstaged")
		view.select_explorer_file(explorer, tracked_node and tracked_node.data or nil)

		h.wait_for(function()
			return explorer.current_file_path == "tracked.lua"
				and session.modified_win
				and vim.api.nvim_win_is_valid(session.modified_win)
		end, 10000, "CodeDiff revision modified window was not ready")

		vim.api.nvim_set_current_win(session.modified_win)
		view.close_view(h.get_codediff_lifecycle)

		h.wait_for(function()
			return lifecycle.get_session(tabpage) == nil
		end, 10000, "CodeDiff revision explorer did not close")

		view.resume_last_session(h.get_codediff_lifecycle)

		local resumed_explorer
		h.wait_for(function()
			for _, current_tabpage in ipairs(vim.api.nvim_list_tabpages()) do
				local current_explorer = lifecycle.get_explorer(current_tabpage)
				if
					current_explorer
					and current_explorer.base_revision == head_revision
					and current_explorer.target_revision == "WORKING"
					and current_explorer.current_file_path == "tracked.lua"
				then
					resumed_explorer = current_explorer
					return true
				end
			end

			return false
		end, 15000, "CodeDiff did not resume the revision explorer")

		h.wait_for(function()
			return h.find_tree_entry(resumed_explorer, "tracked.lua", "unstaged")
				and not h.find_tree_entry(resumed_explorer, "scratch.md", "unstaged")
		end, 10000, "Resume brought untracked files back into the explorer")

		assert.is_not_nil(explorer)
	end)

	it("can open the current file with explorer selection and diff focus", function()
		repo = create_two_modified_files_repo()

		local _, session, explorer = h.open_status_explorer(repo, "alpha.lua", {
			hide_untracked = true,
			focus_diff = true,
		})

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		h.wait_for(function()
			return session
				and session.modified_win
				and vim.api.nvim_win_is_valid(session.modified_win)
				and vim.api.nvim_get_current_win() == session.modified_win
		end, 10000, "CodeDiff did not focus the modified diff window")
	end)

	it("updates the current CodeDiff file position without echoing during navigation", function()
		repo = create_two_modified_files_repo()

		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return require("user.codediff.view").get_file_position(tabpage) == "1/2"
		end, 10000, "Initial CodeDiff file position was not available")

		assert.is_false(echo_capture.contains("1/2 files"))

		assert.is_true(require("codediff").next_file())

		h.wait_for(function()
			return explorer.current_file_path == "beta.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not navigate to beta.lua")

		h.wait_for(function()
			return require("user.codediff.view").get_file_position(tabpage) == "2/2"
		end, 10000, "Updated CodeDiff file position was not available")

		assert.is_false(echo_capture.contains("2/2 files"))
	end)

	it("keeps untracked files hidden after refreshing revision explorers", function()
		repo = create_modified_and_untracked_repo()
		vim.fn.chdir(repo.dir)

		vim.cmd("CodeDiff HEAD")

		local lifecycle = h.get_codediff_lifecycle()
		local tabpage
		local explorer
		h.wait_for(function()
			for _, tp in ipairs(vim.api.nvim_list_tabpages()) do
				local current_explorer = lifecycle.get_explorer(tp)
				if
					current_explorer
					and current_explorer.base_revision
					and current_explorer.target_revision == "WORKING"
				then
					tabpage = tp
					explorer = current_explorer
					return true
				end
			end

			return false
		end, 15000, "Revision CodeDiff explorer was not ready")

		require("user.codediff.view").set_explorer_options(h.get_codediff_lifecycle, tabpage, {
			hide_untracked = true,
		})

		require("codediff.ui.explorer.refresh").refresh(explorer)

		h.wait_for(function()
			return h.find_tree_entry(explorer, "tracked.lua", "unstaged")
				and not h.find_tree_entry(explorer, "scratch.md", "unstaged")
		end, 10000, "Refresh brought untracked files back into the explorer")
	end)

	it("opens PR diffs against HEAD without dirty working tree changes", function()
		repo = create_pr_diff_repo_with_dirty_worktree()
		vim.fn.chdir(repo.dir)

		with_branch_and_mode("main", "PR diff", function()
			require("user.codediff").open_pr_diff_against_branch()
		end)

		local _, session, explorer =
			h.wait_for_explorer_session({ file_path = "feature.lua" }, 15000, "PR CodeDiff explorer was not ready")

		assert.is_not_nil(session)
		assert.are_not.equal("WORKING", session.modified_revision)
		assert.is_not_nil(h.find_tree_entry(explorer, "feature.lua", "unstaged"))
		assert.is_nil(h.find_tree_entry(explorer, "tracked.lua", "unstaged"))
	end)

	it("opens staged added files in an editable real buffer", function()
		repo = create_staged_added_file_repo()

		local tabpage, session, explorer = h.open_status_explorer(repo, "new.lua", { hide_untracked = false })

		h.wait_for(function()
			return explorer.current_file_path == "new.lua" and explorer.current_file_group == "staged"
		end, 10000, "CodeDiff did not select new.lua in the staged group")

		h.wait_for(function()
			local _, modified_bufnr = h.get_codediff_lifecycle().get_buffers(tabpage)
			return modified_bufnr
				and vim.api.nvim_buf_is_valid(modified_bufnr)
				and vim.bo[modified_bufnr].modifiable
				and vim.api.nvim_buf_get_name(modified_bufnr) == repo.path("new.lua")
		end, 10000, "Staged added file did not open as an editable real buffer")

		assert.is_not_nil(session)
	end)

	it("re-stages a staged added file after saving edits", function()
		repo = create_staged_added_file_repo()

		local tabpage, _, explorer = h.open_status_explorer(repo, "new.lua", { hide_untracked = false })

		h.wait_for(function()
			return explorer.current_file_path == "new.lua" and explorer.current_file_group == "staged"
		end, 10000, "CodeDiff did not select new.lua in the staged group")

		local modified_bufnr
		h.wait_for(function()
			local _, bufnr = h.get_codediff_lifecycle().get_buffers(tabpage)
			modified_bufnr = bufnr
			return modified_bufnr and vim.api.nvim_buf_is_valid(modified_bufnr) and vim.bo[modified_bufnr].modifiable
		end, 10000, "Staged added file did not open as an editable real buffer")

		h.focus_modified_window(tabpage)
		vim.api.nvim_buf_set_lines(modified_bufnr, 0, -1, false, { "return 'newer'" })
		vim.cmd("write")

		h.wait_for(function()
			return vim.trim(repo.git_ok({ "status", "--short", "new.lua" })) == "A  new.lua"
		end, 10000, "Saved staged added file was not re-staged")
	end)

	it("close_all_views tears down every active codediff session", function()
		local view = require("user.codediff.view")
		local lifecycle = h.get_codediff_lifecycle()

		repo = create_two_modified_files_repo()
		local first_tabpage = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		vim.cmd("tabnew")
		view.open_status_explorer(repo.dir, "beta.lua", { hide_untracked = true }, h.get_codediff_lifecycle)
		local second_tabpage
		h.wait_for(function()
			for _, tp in ipairs(vim.api.nvim_list_tabpages()) do
				if tp ~= first_tabpage then
					local session = lifecycle.get_session(tp)
					if session and session.mode == "explorer" then
						second_tabpage = tp
						return true
					end
				end
			end
			return false
		end, 15000, "Second CodeDiff explorer did not open")

		assert.is_not_nil(lifecycle.get_session(first_tabpage))
		assert.is_not_nil(lifecycle.get_session(second_tabpage))

		view.close_all_views(h.get_codediff_lifecycle)

		h.wait_for(function()
			return lifecycle.get_session(first_tabpage) == nil and lifecycle.get_session(second_tabpage) == nil
		end, 10000, "close_all_views did not tear down both sessions")
	end)

	it("closes the prior codediff session when opening codediff again", function()
		local lifecycle = h.get_codediff_lifecycle()

		repo = create_two_modified_files_repo()
		vim.fn.chdir(repo.dir)
		local first_tabpage = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })
		assert.is_not_nil(lifecycle.get_session(first_tabpage))

		vim.cmd("tabnew " .. vim.fn.fnameescape(repo.path("beta.lua")))

		require("user.codediff").project_diff()

		h.wait_for(function()
			return lifecycle.get_session(first_tabpage) == nil
		end, 10000, "Opening codediff again did not close the prior session")

		h.wait_for_explorer_session({}, 15000, "CodeDiff did not reopen after closing the prior session")
	end)
end)

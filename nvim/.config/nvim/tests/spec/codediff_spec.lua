local h = require("tests.helpers.codediff")

local original_cwd
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

describe("local CodeDiff workflow", function()
	before_each(function()
		original_cwd = vim.fn.getcwd()
		h.reset_editor()
		echo_capture = h.capture_echoes()
	end)

	after_each(function()
		if echo_capture then
			echo_capture.restore()
			echo_capture = nil
		end

		vim.fn.chdir(original_cwd)
		h.reset_editor()
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
end)

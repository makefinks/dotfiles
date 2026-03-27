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
		local actions = require("plugins.git.codediff.actions")

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
		local actions = require("plugins.git.codediff.actions")

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
		local actions = require("plugins.git.codediff.actions")

		repo = create_two_modified_files_repo()
		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

		local first_modified_bufnr
		h.wait_for(function()
			first_modified_bufnr = h.focus_modified_window(tabpage)
			return h.buffer_has_keymap(first_modified_bufnr, "<leader>gs")
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
				and h.buffer_has_keymap(second_modified_bufnr, "<leader>gs")
				and h.buffer_has_keymap(second_modified_bufnr, "ff")
		end, 15000, "Staging did not advance to beta.lua")

		if vim.api.nvim_buf_is_valid(first_modified_bufnr) then
			assert.is_false(h.buffer_has_keymap(first_modified_bufnr, "<leader>gs"))
			assert.is_false(h.buffer_has_keymap(first_modified_bufnr, "ff"))
		end
	end)

	it("closes codediff and opens the working tree file at the diff cursor", function()
		local view = require("plugins.git.codediff.view")

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

	it("echoes the current CodeDiff file position during navigation", function()
		repo = create_two_modified_files_repo()

		local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

		h.wait_for(function()
			return require("plugins.git.codediff.view").get_file_position(tabpage) == "1/2"
		end, 10000, "Initial CodeDiff file position was not available")

		h.wait_for(function()
			return echo_capture.contains("1/2 files")
		end, 10000, "Initial CodeDiff file position message was not echoed")

		assert.is_true(require("codediff").next_file())

		h.wait_for(function()
			return explorer.current_file_path == "beta.lua" and explorer.current_file_group == "unstaged"
		end, 10000, "CodeDiff did not navigate to beta.lua")

		h.wait_for(function()
			return echo_capture.contains("2/2 files")
		end, 10000, "Updated CodeDiff file position message was not echoed")
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

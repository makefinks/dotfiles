local h = require("tests.helpers.codediff")

local dir
local repo

local function lines()
	local result = {}
	for i = 1, 120 do
		result[i] = string.format("local value_%d = '%s'", i, string.rep("x", 100))
	end
	return result
end

local function open_files()
	dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local before = lines()
	local after = vim.deepcopy(before)
	after[10] = "local changed = true"
	table.insert(after, 11, "local added = true")
	vim.fn.writefile(before, dir .. "/before.lua")
	vim.fn.writefile(after, dir .. "/after.lua")
	vim.cmd(
		"CodeDiff file " .. vim.fn.fnameescape(dir .. "/before.lua") .. " " .. vim.fn.fnameescape(dir .. "/after.lua")
	)
	local tabpage
	h.wait_for(function()
		for _, tp in ipairs(vim.api.nvim_list_tabpages()) do
			local session = h.get_codediff_lifecycle().get_session(tp)
			if session and session.modified.absolute == dir .. "/after.lua" and session.stored_diff_result then
				tabpage = tp
				return true
			end
		end
		return false
	end)
	return tabpage, h.get_codediff_lifecycle().get_session(tabpage)
end

local function position(win, line, topline)
	vim.api.nvim_set_current_win(win)
	vim.wo[win].scrolloff = 0
	vim.fn.winrestview({ lnum = line, col = 20, topline = topline, leftcol = 5 })
	return vim.fn.winsaveview()
end

local function assert_view(win, expected)
	local actual = vim.api.nvim_win_call(win, vim.fn.winsaveview)
	for _, field in ipairs({ "lnum", "col", "topline", "leftcol" }) do
		assert.equals(expected[field], actual[field], field)
	end
end

local function toggle(tabpage)
	h.wait_for(function()
		return vim.fn.maparg("t", "n", false, true).desc == "Toggle diff layout preserving position"
	end)
	local mapping = vim.fn.maparg("t", "n", false, true)
	assert.equals("Toggle diff layout preserving position", mapping.desc)
	mapping.callback()
	h.wait_for(function()
		local session = h.get_codediff_lifecycle().get_session(tabpage)
		return session and not session.user_layout_pending
	end, 10000, "Layout position was not restored")
end

describe("CodeDiff layout positions", function()
	before_each(function()
		require("user.codediff").close_all_views()
		h.reset_editor()
	end)
	after_each(function()
		require("user.codediff").close_all_views()
		h.reset_editor()
		if dir then
			vim.fn.delete(dir, "rf")
			dir = nil
		end
		if repo then
			repo.cleanup()
			repo = nil
		end
	end)

	it("restores the modified pane and remembers a separate inline position", function()
		local tabpage, session = open_files()
		local side_view = position(session.modified_win, 70, 65)
		toggle(tabpage)
		assert.equals("inline", session.layout)
		assert.equals(side_view.lnum, vim.api.nvim_win_get_cursor(session.modified_win)[1])
		local inline_view = position(session.modified_win, 90, 85)
		toggle(tabpage)
		assert.equals("side-by-side", session.layout)
		assert_view(session.modified_win, side_view)
		assert.equals(session.modified_win, vim.api.nvim_get_current_win())
		toggle(tabpage)
		assert_view(session.modified_win, inline_view)
	end)

	it("restores both panes and focus when toggling from the original pane", function()
		local tabpage, session = open_files()
		local modified = position(session.modified_win, 70, 65)
		local original = position(session.original_win, 69, 64)
		toggle(tabpage)
		assert.equals(69, session.user_layout_views["side-by-side"].original.lnum)
		toggle(tabpage)
		assert_view(session.original_win, original)
		assert_view(session.modified_win, modified)
		assert.equals(session.original_win, vim.api.nvim_get_current_win())
	end)

	it("restores positions after asynchronous Git content loading", function()
		repo = h.create_temp_git_repo()
		repo.write_file("demo.lua", lines())
		repo.git_ok({ "add", "demo.lua" })
		local after = lines()
		after[10] = "local changed = true"
		repo.write_file("demo.lua", after)
		local tabpage, session = h.open_status_explorer(repo, "demo.lua")
		h.wait_for(function()
			return session.stored_diff_result ~= nil and session.original_revision == ":0"
		end)
		local expected = position(session.modified_win, 70, 65)
		toggle(tabpage)
		toggle(tabpage)
		assert_view(session.modified_win, expected)
	end)

	it("does not reuse positions saved for another file", function()
		local tabpage, session = open_files()
		position(session.modified_win, 70, 65)
		toggle(tabpage)
		position(session.modified_win, 90, 85)
		toggle(tabpage)
		vim.fn.writefile(lines(), dir .. "/other.lua")
		require("codediff.ui.view").update(tabpage, {
			mode = "standalone",
			original = { absolute = dir .. "/before.lua", relative = "" },
			modified = { absolute = dir .. "/other.lua", relative = "" },
		}, false)
		h.wait_for(function()
			return session.stored_diff_result ~= nil
		end)
		position(session.modified_win, 30, 25)
		toggle(tabpage)
		assert.equals(30, vim.api.nvim_win_get_cursor(session.modified_win)[1])
	end)
end)

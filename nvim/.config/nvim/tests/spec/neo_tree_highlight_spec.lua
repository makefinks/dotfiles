local search = require("user.neo_tree_search")
local namespace = vim.api.nvim_create_namespace("UserNeoTreeFilterMatch")

describe("Neo-tree filter match highlighting", function()
	local buffer
	local state

	local function render(name, pattern, node_type)
		local line = "  📄 " .. name
		vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { line })
		state.search_pattern = pattern
		state.tree = {
			get_node = function(_, row)
				assert.equals(1, row)
				return { name = name, type = node_type or "file" }
			end,
		}
		search.highlight(state)
		assert.same({ line }, vim.api.nvim_buf_get_lines(buffer, 0, -1, false))
		local matches = {}
		for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
			assert.equals("NeoTreeFilterMatch", mark[4].hl_group)
			matches[#matches + 1] = line:sub(mark[3] + 1, mark[4].end_col)
		end
		return matches
	end

	before_each(function()
		buffer = vim.api.nvim_create_buf(false, true)
		state = { name = "filesystem", bufnr = buffer }
	end)

	after_each(function()
		vim.api.nvim_buf_delete(buffer, { force = true })
	end)

	it("highlights contiguous matches without changing rendered text", function()
		assert.same({ "tree" }, render("neo_tree.lua", "tree"))
	end)

	it("does not highlight scattered fuzzy matches", function()
		assert.same({}, render("neo_tree.lua", "nt"))
	end)

	it("highlights every occurrence", function()
		assert.same({ "test", "test" }, render("test_test.lua", "test"))
	end)

	it("clears old highlights when the filter is cleared or absent", function()
		render("neo_tree.lua", "tree")
		assert.same({}, render("neo_tree.lua", ""))
		render("neo_tree.lua", "tree")
		assert.same({}, render("neo_tree.lua", nil))
	end)

	it("does not highlight unmatched names or message nodes", function()
		assert.same({}, render("neo_tree.lua", "xyz"))
		assert.same({}, render("neo_tree.lua", "tree", "message"))
	end)

	it("matches folder names case insensitively", function()
		assert.same({ "Src" }, render("Src", "src", "directory"))
	end)

	it("uses byte offsets for Unicode filenames and icons", function()
		assert.same({ "é" }, render("café.lua", "é"))
	end)

	it("treats punctuation literally", function()
		assert.same({ "[1]" }, render("file[1].lua", "[1]"))
		assert.same({ "\\" }, render("file\\name.lua", "\\"))
	end)

	it("keeps gitsigns.lua and description unsplit", function()
		assert.same({ "gitsigns" }, render("gitsigns.lua", "gitsigns"))
		assert.same({ "scrip" }, render("description", "scrip"))
	end)

	it("ignores closed buffers", function()
		search.highlight({ name = "filesystem", bufnr = -1, search_pattern = "tree" })
	end)

	it("does not highlight other Neo-tree sources", function()
		state.name = "buffers"
		assert.same({}, render("neo_tree.lua", "tree"))
	end)
end)

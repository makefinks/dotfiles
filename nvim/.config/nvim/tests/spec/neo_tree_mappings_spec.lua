local opts = require("plugins.navigation.neo-tree").opts
local mappings = opts.window.mappings

describe("Neo-tree navigation mappings", function()
	it("expands and collapses folders with s", function()
		assert.equals("toggle_node", mappings.s)
	end)

	it("opens vertical splits with Ctrl+Enter", function()
		assert.equals("open_vsplit", mappings["<C-CR>"])
	end)

	it("recursively expands the selected folder with Shift+S", function()
		assert.equals("expand_all_subnodes", opts.filesystem.window.mappings.S)
	end)

	it("recursively collapses the selected folder with Shift+C", function()
		assert.equals("close_all_subnodes", opts.filesystem.window.mappings.C)
	end)
end)

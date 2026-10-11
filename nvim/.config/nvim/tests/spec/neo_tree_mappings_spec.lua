local mappings = require("plugins.navigation.neo-tree").opts.window.mappings

describe("Neo-tree navigation mappings", function()
	it("expands and collapses folders with s", function()
		assert.equals("toggle_node", mappings.s)
	end)

	it("opens vertical splits with Ctrl+Enter", function()
		assert.equals("open_vsplit", mappings["<C-CR>"])
	end)
end)

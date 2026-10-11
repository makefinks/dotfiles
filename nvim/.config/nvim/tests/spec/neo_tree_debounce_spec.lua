local search = require("user.neo_tree_search")

describe("Neo-tree search debounce", function()
	local original_utils
	local utils
	local calls

	before_each(function()
		original_utils = package.loaded["neo-tree.utils"]
		calls = {}
		utils = {
			debounce = function(...)
				calls[#calls + 1] = { ... }
				return "result"
			end,
		}
		package.loaded["neo-tree.utils"] = utils
	end)

	after_each(function()
		package.loaded["neo-tree.utils"] = original_utils
	end)

	it("uses 50 ms for every filter query length and preserves other arguments", function()
		search.setup()
		local callback = function() end
		for _, delay in ipairs({ 500, 400, 200, 100 }) do
			assert.equals("result", utils.debounce("filesystem_filter", callback, delay, "strategy", "action"))
			assert.same({ "filesystem_filter", callback, 50, "strategy", "action" }, calls[#calls])
		end
	end)

	it("leaves other debounce delays unchanged", function()
		search.setup()
		local callback = function() end
		utils.debounce("filesystem_navigate", callback, 100, "strategy")
		assert.same({ "filesystem_navigate", callback, 100, "strategy" }, calls[1])
	end)

	it("does not wrap debounce again on repeated setup", function()
		search.setup()
		local debounce = utils.debounce
		search.setup()
		assert.equals(debounce, utils.debounce)
	end)
end)

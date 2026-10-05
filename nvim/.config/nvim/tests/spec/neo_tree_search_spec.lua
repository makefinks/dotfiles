local filesystem = require("plugins.navigation.neo-tree").opts.filesystem

describe("Neo-tree folder search mappings", function()
	local original_fff
	local original_lazy
	local calls
	local loaded_plugins
	local folder = vim.fn.getcwd() .. "/tests/fixtures/picker"

	local function state_for(path, node_type)
		return {
			tree = {
				get_node = function()
					return {
						type = node_type,
						get_id = function()
							return path
						end,
					}
				end,
			},
		}
	end

	local function invoke(key, state)
		filesystem.commands[filesystem.window.mappings[key]](state)
	end

	before_each(function()
		original_fff = package.loaded.fff
		original_lazy = package.loaded.lazy
		calls = {}
		package.loaded.fff = {
			find_files = function(opts)
				calls[#calls + 1] = { picker = "files", opts = opts }
			end,
			live_grep = function(opts)
				calls[#calls + 1] = { picker = "grep", opts = opts }
			end,
		}
		package.loaded.lazy = {
			load = function(opts)
				loaded_plugins = opts.plugins
			end,
		}
	end)

	after_each(function()
		package.loaded.fff = original_fff
		package.loaded.lazy = original_lazy
	end)

	it("removes inherited lowercase folder-search mappings", function()
		assert.is_false(filesystem.window.mappings.ff)
		assert.is_false(filesystem.window.mappings.fw)
	end)

	it("opens FF at the selected folder without changing Neovim's cwd or search", function()
		local cwd = vim.fn.getcwd()
		local search = vim.fn.getreg("/")
		invoke("FF", state_for(folder, "directory"))
		assert.same({ picker = "files", opts = { cwd = folder } }, calls[1])
		assert.same({ "fff.nvim" }, loaded_plugins)
		assert.equals(cwd, vim.fn.getcwd())
		assert.equals(search, vim.fn.getreg("/"))
	end)

	it("opens FW at the selected folder with the existing grep modes", function()
		invoke("FW", state_for(folder, "directory"))
		assert.same({
			picker = "grep",
			opts = { cwd = folder, title = "FFFuzzy Grep", grep = { modes = { "plain", "fuzzy" } } },
		}, calls[1])
	end)

	it("uses the parent folder for files with either mapping", function()
		for _, key in ipairs({ "FF", "FW" }) do
			invoke(key, state_for(folder .. "/file with spaces.txt", "file"))
			assert.equals(folder, calls[#calls].opts.cwd)
		end
	end)

	it("ignores missing and non-file nodes", function()
		invoke("FF", {})
		invoke("FW", { tree = { get_node = function() end } })
		invoke("FF", state_for("hidden items", "message"))
		assert.equals(0, #calls)
	end)
end)

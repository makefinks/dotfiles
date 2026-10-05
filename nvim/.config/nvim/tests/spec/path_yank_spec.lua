local mappings = require("plugins.core.astrocore").opts.mappings
local virtual_file = require("codediff.core.virtual_file")

describe("file path yank mappings", function()
	local original_buffer
	local original_setreg
	local original_snacks
	local original_manager
	local buffer
	local registers
	local git_root
	local file_path = "nvim/.config/nvim/tests/spec/codediff_spec.lua"

	local function name_buffer(name)
		vim.api.nvim_buf_set_name(buffer, name)
	end

	local function assert_yank(mode, key, expected)
		mappings[mode][key][1]()
		assert.equals(expected, registers["+"])
		assert.equals(expected, registers['"'])
	end

	before_each(function()
		original_buffer = vim.api.nvim_get_current_buf()
		original_setreg = vim.fn.setreg
		original_snacks = _G.Snacks
		original_manager = package.loaded["neo-tree.sources.manager"]
		registers = {}
		vim.fn.setreg = function(register, value)
			registers[register] = value
		end
		_G.Snacks = { notifier = { notify = function() end } }
		git_root = vim.fs.joinpath(vim.fn.getcwd(), "dotfiles")
		buffer = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buffer)
		vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "one", "two", "three", "four" })
	end)

	after_each(function()
		vim.cmd("normal! \27")
		vim.fn.setreg = original_setreg
		_G.Snacks = original_snacks
		package.loaded["neo-tree.sources.manager"] = original_manager
		vim.api.nvim_set_current_buf(original_buffer)
		vim.api.nvim_buf_delete(buffer, { force = true })
	end)

	it("copies the relative path of a staged file instead of its virtual URI", function()
		name_buffer(virtual_file.create_url(git_root, ":0", file_path))
		assert_yank("n", "<Leader>yp", "dotfiles/" .. file_path)
	end)

	it("copies the absolute path of a staged file", function()
		name_buffer(virtual_file.create_url(git_root, ":0", file_path))
		assert_yank("n", "<Leader>yP", vim.fs.joinpath(git_root, file_path))
	end)

	it("resolves commit, symbolic, and conflict-stage revisions", function()
		for _, revision in ipairs({ "abc123", "abc123^", "HEAD", "HEAD~1", ":1:", ":2:", ":3:" }) do
			name_buffer(virtual_file.create_url(git_root, revision, file_path))
			assert_yank("n", "<Leader>yp", "dotfiles/" .. file_path)
			assert_yank("n", "<Leader>yP", vim.fs.joinpath(git_root, file_path))
		end
	end)

	it("preserves spaces in repository and file paths", function()
		local path = vim.fs.joinpath(git_root .. " with spaces", "folder/file name.lua")
		name_buffer(virtual_file.create_url(git_root .. " with spaces", ":0", "folder/file name.lua"))
		assert_yank("n", "<Leader>yp", "dotfiles with spaces/folder/file name.lua")
		assert_yank("n", "<Leader>yP", path)
	end)

	it("includes selected line ranges with the resolved paths", function()
		name_buffer(virtual_file.create_url(git_root, ":0", file_path))
		vim.cmd("normal! 3GV2G")
		assert_yank("x", "<Leader>yp", "dotfiles/" .. file_path .. ":2-3")
		assert_yank("x", "<Leader>yP", vim.fs.joinpath(git_root, file_path) .. ":2-3")
	end)

	it("includes a single selected line with the resolved paths", function()
		name_buffer(virtual_file.create_url(git_root, ":0", file_path))
		vim.cmd("normal! 2GV")
		assert_yank("x", "<Leader>yp", "dotfiles/" .. file_path .. ":2")
		assert_yank("x", "<Leader>yP", vim.fs.joinpath(git_root, file_path) .. ":2")
	end)

	it("keeps ordinary file paths unchanged", function()
		name_buffer(vim.fs.joinpath(git_root, file_path))
		assert_yank("n", "<Leader>yp", "dotfiles/" .. file_path)
		assert_yank("n", "<Leader>yP", vim.fs.joinpath(git_root, file_path))
	end)

	it("keeps resolving the selected Neo-tree node", function()
		vim.bo[buffer].filetype = "neo-tree"
		name_buffer("neo-tree filesystem")
		package.loaded["neo-tree.sources.manager"] = {
			get_state_for_window = function()
				return {
					tree = {
						get_node = function()
							return {
								get_id = function()
									return vim.fs.joinpath(git_root, file_path)
								end,
							}
						end,
					},
				}
			end,
		}
		assert_yank("n", "<Leader>yp", "dotfiles/" .. file_path)
		assert_yank("n", "<Leader>yP", vim.fs.joinpath(git_root, file_path))
	end)
end)

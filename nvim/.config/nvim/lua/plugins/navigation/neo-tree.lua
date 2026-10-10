local never_show = {
	"node_modules",
	".venv",
	"venv",
	"__pycache__",
	".pytest_cache",
	"dist",
	"build",
	".next",
	".nuxt",
	"target",
	"cdk.out",
}

local function exclude_never_show(cmd, _, _, args)
	if cmd ~= "fd" and cmd ~= "fdfind" then
		return args
	end

	for _, name in ipairs(never_show) do
		args[#args + 1] = "--exclude"
		args[#args + 1] = name
	end

	return args
end

local function search_selected_folder(state, picker)
	local node = state.tree and state.tree:get_node() or nil
	if not node or (node.type ~= "directory" and node.type ~= "file") then
		return
	end

	local path = node:get_id()
	local folder = node.type == "directory" and path or vim.fn.fnamemodify(path, ":h")
	local opts = { cwd = folder }
	if picker == "live_grep" then
		opts.title = "FFFuzzy Grep"
		opts.grep = { modes = { "plain", "fuzzy" } }
	end

	local ok_lazy, lazy = pcall(require, "lazy")
	if ok_lazy and lazy.load then
		lazy.load({ plugins = { "fff.nvim" } })
	end

	local ok, fff = pcall(require, "fff")
	if ok and fff[picker] then
		fff[picker](opts)
		return
	end

	local fallback_ok, snacks = pcall(require, "snacks")
	local fallback = picker == "find_files" and "files" or "grep"
	if fallback_ok and snacks.picker and snacks.picker[fallback] then
		snacks.picker[fallback](opts)
	end
end

return {
	"nvim-neo-tree/neo-tree.nvim",
	opts = {
		clipboard = {
			sync = "universal",
		},
		window = {
			width = 50,
			mappings = {
				["<C-CR>"] = "open_vsplit",
				["s"] = "none",
			},
			mapping_options = {
				noremap = true,
				nowait = true,
			},
		},
		filesystem = {
			window = {
				mappings = {
					["/"] = "fuzzy_finder",
					["ff"] = false,
					["fw"] = false,
					["FF"] = "find_files_in_dir",
					["FW"] = "grep_in_dir",
				},
			},
			commands = {
				find_files_in_dir = function(state)
					search_selected_folder(state, "find_files")
				end,
				grep_in_dir = function(state)
					search_selected_folder(state, "live_grep")
				end,
			},
			find_args = exclude_never_show,
			filtered_items = {
				visible = false,
				hide_dotfiles = false,
				hide_gitignored = false,
				hide_hidden = true,
				never_show = never_show,
			},
			follow_current_file = {
				enabled = true,
				leave_dirs_open = true,
			},
		},
		default_component_configs = {
			modified = {
				symbol = "[+]",
				highlight = "NeoTreeModified",
			},
			git_status = {
				symbols = {
					added = "",
					modified = "",
					deleted = "",
					renamed = "",
					untracked = "",
					ignored = "",
					unstaged = "󰄱",
					staged = "",
					conflict = "",
				},
			},
		},
	},
}

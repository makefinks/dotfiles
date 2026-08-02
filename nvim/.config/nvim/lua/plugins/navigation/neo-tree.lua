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

return {
	"nvim-neo-tree/neo-tree.nvim",
	opts = {
		clipboard = {
			sync = "universal",
		},
		window = {
			width = 50,
			mapping_options = {
				noremap = true,
				nowait = true,
			},
		},
		filesystem = {
			window = {
				mappings = {
					["/"] = "fuzzy_finder",
				},
			},
			commands = {
				find_files_in_dir = function()
					local ok_lazy, lazy = pcall(require, "lazy")
					if ok_lazy and lazy and lazy.load then
						lazy.load({ plugins = { "fff.nvim" } })
					end

					local ok, fff = pcall(require, "fff")
					if ok and fff and fff.find_files then
						fff.find_files()
						return
					end

					local fallback_ok, snacks = pcall(require, "snacks")
					if fallback_ok and snacks.picker and snacks.picker.files then
						snacks.picker.files()
						return
					end
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

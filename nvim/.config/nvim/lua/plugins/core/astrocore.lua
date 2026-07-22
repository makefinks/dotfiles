-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---Resolve the current relative path, including the selected Neo-tree node.
local function get_current_path()
	if vim.bo.filetype == "neo-tree" then
		-- Neo-tree uses a synthetic buffer name, so read the selected node instead.
		local ok, manager = pcall(require, "neo-tree.sources.manager")
		if ok then
			local state = manager.get_state_for_window()
			local node = state and state.tree and state.tree:get_node() or nil
			local node_path = node and node:get_id() or nil
			if node_path and node_path ~= "" then
				return vim.fn.fnamemodify(node_path, ":.")
			end
		end
	end

	return vim.fn.expand("%:.")
end

local function get_current_absolute_path()
	if vim.bo.filetype == "neo-tree" then
		local ok, manager = pcall(require, "neo-tree.sources.manager")
		if ok then
			local state = manager.get_state_for_window()
			local node = state and state.tree and state.tree:get_node() or nil
			local node_path = node and node:get_id() or nil
			if node_path and node_path ~= "" then
				return vim.fn.fnamemodify(node_path, ":p")
			end
		end
	end

	return vim.fn.expand("%:p")
end

local supported_external_extensions = {
	avif = true,
	docx = true,
	epub = true,
	gif = true,
	html = true,
	htm = true,
	jpeg = true,
	jpg = true,
	mkv = true,
	mov = true,
	mp3 = true,
	mp4 = true,
	pdf = true,
	pptx = true,
	svg = true,
	wav = true,
	webm = true,
	webp = true,
	xlsx = true,
}

local function yank_path(path, title)
	if path == nil or path == "" then
		return
	end

	vim.fn.setreg("+", path)
	vim.fn.setreg('"', path)
	Snacks.notifier.notify("Copied: " .. path, "info", { title = title })
end

local function get_system_opener_command()
	if vim.fn.has("macunix") == 1 then
		return "open"
	end
	if vim.fn.has("wsl") == 1 and vim.fn.executable("explorer.exe") == 1 then
		return "explorer.exe"
	end
	if vim.fn.executable("xdg-open") == 1 then
		return "xdg-open"
	end
end

local function open_current_folder_in_file_manager()
	local path = get_current_path()
	if path == nil or path == "" then
		Snacks.notifier.notify("No file path to open", "warn", { title = "File Manager" })
		return
	end

	local absolute_path = vim.fn.fnamemodify(path, ":p")
	local dir = vim.fn.isdirectory(absolute_path) == 1 and absolute_path or vim.fn.fnamemodify(absolute_path, ":h")
	local command = get_system_opener_command()
	if command == nil then
		Snacks.notifier.notify("No supported file manager command found", "error", { title = "File Manager" })
		return
	end

	local job_id = vim.fn.jobstart({ command, dir }, { detach = true })
	if job_id <= 0 then
		Snacks.notifier.notify("Failed to open file manager", "error", { title = "File Manager" })
	end
end

local function open_current_file_externally()
	local path = get_current_absolute_path()
	if path == nil or path == "" then
		Snacks.notifier.notify("No file path to open", "warn", { title = "External Viewer" })
		return
	end

	local extension = vim.fn.fnamemodify(path, ":e"):lower()
	if not supported_external_extensions[extension] then
		Snacks.notifier.notify("This file type is not supported", "warn", { title = "External Viewer" })
		return
	end

	local absolute_path = vim.fn.fnamemodify(path, ":p")
	if vim.fn.filereadable(absolute_path) ~= 1 then
		Snacks.notifier.notify("File is not readable: " .. absolute_path, "warn", { title = "External Viewer" })
		return
	end

	local command = get_system_opener_command()
	if command == nil then
		Snacks.notifier.notify("No supported external opener found", "error", { title = "External Viewer" })
		return
	end

	local job_id = vim.fn.jobstart({ command, absolute_path }, { detach = true })
	if job_id <= 0 then
		Snacks.notifier.notify("Failed to open file externally", "error", { title = "External Viewer" })
	end
end

---@type LazySpec
return {
	"AstroNvim/astrocore",
	---@type AstroCoreOpts
	opts = {
		-- Configure core features of AstroNvim
		features = {
			large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
			autopairs = true, -- enable autopairs at start
			cmp = true, -- enable completion at start
			highlighturl = true, -- highlight URLs at start
			notifications = true, -- enable notifications at start
		},
		-- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
		diagnostics = {
			virtual_text = true,
			virtual_lines = false,
			underline = true,
		},
		-- vim options can be configured here
		options = {
			opt = { -- vim.opt.<key>
				relativenumber = true, -- sets vim.opt.relativenumber
				number = true, -- sets vim.opt.number
				hlsearch = true, -- keep search highlights enabled
				incsearch = true, -- stop / and ? from jumping while typing
				ignorecase = true, -- case-insensitive search
				smartcase = false, -- keep search fully case-insensitive
				spell = false, -- sets vim.opt.spell
				signcolumn = "yes", -- sets vim.opt.signcolumn to yes
				wrap = false, -- sets vim.opt.wrap
			},
			g = { -- vim.g.<key>
				-- configure global vim variables (vim.g)
				-- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
				-- This can be found in the `lua/lazy_setup.lua` file
			},
		},
		-- Disable AstroNvim's auto-toggle of hlsearch so matches stay highlighted
		on_keys = {
			auto_hlsearch = false,
		},
		-- Mappings can be configured through AstroCore as well.
		-- NOTE: keycodes follow the casing in the vimdocs. For example, `<Leader>` must be capitalized
		mappings = {
			-- first key is the mode
			n = {
				["<Leader>c"] = false,
				["<Leader>ff"] = false,
				["<Leader>fo"] = {
					open_current_folder_in_file_manager,
					desc = "Open folder in file manager",
				},
				["<Leader>fO"] = {
					open_current_file_externally,
					desc = "Open file externally",
				},
				["<Leader>fs"] = false,
				["<Leader>fw"] = false,
				["<Esc>"] = {
					function()
						if vim.v.hlsearch == 1 then
							vim.cmd.nohlsearch()
						end
					end,
					desc = "Clear search highlight",
				},
				F = {
					function()
						local word = vim.fn.expand("<cword>")
						if word == nil or word == "" then
							return
						end
						local pattern = "\\V\\<" .. vim.fn.escape(word, "\\") .. "\\>"
						vim.fn.setreg("/", pattern)
						vim.opt.hlsearch = true
					end,
					desc = "Search word under cursor (no jump)",
				},
				n = { "nzzzv", desc = "Next search result (centered)" },
				N = { "Nzzzv", desc = "Previous search result (centered)" },
				["<C-o>"] = { "<C-o>zz", desc = "Jump back (centered)" },
				["<C-i>"] = { "<C-i>zz", desc = "Jump forward (centered)" },
				["<Leader>yp"] = {
					function()
						yank_path(get_current_path(), "Path")
					end,
					desc = "Yank relative file path",
				},
				["<Leader>yP"] = {
					function()
						yank_path(get_current_absolute_path(), "Path")
					end,
					desc = "Yank absolute file path",
				},
			},
			x = {
				["<Leader>yp"] = {
					function()
						local path = get_current_path()
						if path == nil or path == "" then
							return
						end
						local start_line = vim.fn.line("v")
						local end_line = vim.api.nvim_win_get_cursor(0)[1]
						local from_line = math.min(start_line, end_line)
						local to_line = math.max(start_line, end_line)
						local selection = from_line == to_line and string.format("%s:%d", path, from_line)
							or string.format("%s:%d-%d", path, from_line, to_line)
						yank_path(selection, "Path + Lines")
					end,
					desc = "Yank relative file path with selected line range",
				},
				["<Leader>yP"] = {
					function()
						local path = get_current_absolute_path()
						if path == nil or path == "" then
							return
						end
						local start_line = vim.fn.line("v")
						local end_line = vim.api.nvim_win_get_cursor(0)[1]
						local from_line = math.min(start_line, end_line)
						local to_line = math.max(start_line, end_line)
						local selection = from_line == to_line and string.format("%s:%d", path, from_line)
							or string.format("%s:%d-%d", path, from_line, to_line)
						yank_path(selection, "Path + Lines")
					end,
					desc = "Yank absolute file path with selected line range",
				},
			},
		},
	},
}

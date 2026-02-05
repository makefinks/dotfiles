local function get_current_repo_file_info()
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" then
		vim.notify("Current buffer is not a file", vim.log.levels.WARN)
		return nil
	end

	local repo = vim.fn.systemlist({ "git", "-C", vim.fn.fnamemodify(file, ":h"), "rev-parse", "--show-toplevel" })[1]
	if vim.v.shell_error ~= 0 or not repo or repo == "" then
		vim.notify("File is not in a git repository", vim.log.levels.ERROR)
		return nil
	end

	local abs = vim.fn.fnamemodify(file, ":p")
	if not vim.startswith(abs, repo .. "/") then
		vim.notify("Could not resolve file path relative to repository", vim.log.levels.ERROR)
		return nil
	end

	return {
		repo = repo,
		rel = abs:sub(#repo + 2),
		filetype = vim.bo.filetype,
	}
end

local function with_branch(callback)
	local ok, snacks = pcall(require, "snacks")
	if ok and snacks.picker and snacks.picker.pick then
		snacks.picker.pick("git_branches", {
			title = "Git Branches",
			confirm = function(picker, item)
				picker:close()
				local branch = item and item.branch
				if not branch or branch == "" then
					vim.notify("No branch selected", vim.log.levels.WARN)
					return
				end
				callback(branch)
			end,
		})
		return
	end

	local branch = vim.fn.input("Branch: ", "main")
	if branch ~= "" then
		callback(branch)
	end
end

local function open_diffview_split(repo, rel, branch)
	if vim.fn.exists(":DiffviewOpen") ~= 2 then
		vim.notify("Diffview is not available", vim.log.levels.ERROR)
		return
	end

	local cmd = string.format(
		"DiffviewOpen %s -C%s -- %s",
		vim.fn.fnameescape(branch),
		vim.fn.fnameescape(repo),
		vim.fn.fnameescape(rel)
	)
	vim.cmd(cmd)

	vim.defer_fn(function()
		local wins = vim.api.nvim_tabpage_list_wins(0)
		for _, win in ipairs(wins) do
			if vim.api.nvim_win_is_valid(win) and vim.wo[win].diff then
				vim.wo[win].foldenable = false
				vim.api.nvim_win_call(win, function()
					vim.cmd("normal! zR")
				end)
			end
		end
	end, 60)
end

local function open_branch_preview(repo, rel, filetype, branch, split_mode)
	local spec = branch .. ":" .. rel
	local content = vim.fn.systemlist({ "git", "-C", repo, "show", spec })
	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to open " .. spec, vim.log.levels.ERROR)
		return
	end

	if split_mode then
		vim.cmd("vsplit")
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buflisted = false
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
	vim.bo[buf].filetype = filetype
	vim.bo[buf].readonly = true
	vim.bo[buf].modifiable = false
	vim.b[buf].is_branch_preview = true

	local ns = vim.api.nvim_create_namespace("branch_preview")
	vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
		virt_lines = {
			{
				{ string.format(" [BRANCH PREVIEW] %s:%s  (q to close) ", branch, rel), "WarningMsg" },
			},
		},
		virt_lines_above = true,
	})

	vim.keymap.set("n", "q", function()
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end, { buffer = buf, silent = true, desc = "Close branch preview buffer" })

	vim.notify(string.format("Branch preview: %s (press q to close)", branch), vim.log.levels.INFO, {
		title = "Git Branch File",
	})
end

local function run_file_in_branch_mode(mode, context, branch)
	if mode == "Diff view" then
		require("vgit").buffer_diff_preview({ branch = branch })
		return
	end

	if mode == "Diff view (split)" then
		open_diffview_split(context.repo, context.rel, branch)
		return
	end

	local split_mode = mode == "Open branch file (split)"
	open_branch_preview(context.repo, context.rel, context.filetype, branch, split_mode)
end

return {
	"tanvirtin/vgit.nvim",
	dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" },
	lazy = true,
	keys = {
		-- Diff views
		{
			"<leader>gd",
			function()
				require("vgit").buffer_diff_preview()
			end,
			desc = "Buffer diff (unified)",
		},
		{
			"<leader>gD",
			function()
				require("vgit").project_diff_preview()
			end,
			desc = "Project diff",
		},
		{
			"<leader>gF",
			function()
				local context = get_current_repo_file_info()
				if not context then
					return
				end

				vim.ui.select(
					{ "Diff view", "Diff view (split)", "Open branch file", "Open branch file (split)" },
					{ prompt = "View mode:" },
					function(mode)
						if not mode then
							return
						end

						with_branch(function(branch)
							run_file_in_branch_mode(mode, context, branch)
						end)
					end
				)
			end,
			desc = "File in another branch",
		},

		-- Conflict resolution
		{
			"<leader>gco",
			function()
				require("vgit").buffer_conflict_accept_current()
			end,
			desc = "Accept current (ours)",
		},
		{
			"<leader>gci",
			function()
				require("vgit").buffer_conflict_accept_incoming()
			end,
			desc = "Accept incoming (theirs)",
		},
		{
			"<leader>gcb",
			function()
				require("vgit").buffer_conflict_accept_both()
			end,
			desc = "Accept both",
		},
	},
	config = function()
		require("vgit").setup({
			settings = {
				live_blame = { enabled = false },
				live_gutter = { enabled = false },
				scene = {
					diff_preference = "unified",
				},
				hls = {
					GitSignsAdd = {
						fg = "#5a9dc7",
						bg = nil,
					},
					GitSignsDelete = {
						fg = "#cc0000",
						bg = nil,
					},
					GitSignsAddLn = {
						fg = "#5a9dc7",
						bg = "#2a3f4d",
					},
					GitSignsDeleteLn = {
						fg = "#cc0000",
						bg = "#4d2a2a",
					},
					GitWordAdd = {
						fg = nil,
						bg = "#2a3f4d",
					},
					GitWordDelete = {
						fg = nil,
						bg = "#4d2a2a",
					},
				},
			},
		})
	end,
}

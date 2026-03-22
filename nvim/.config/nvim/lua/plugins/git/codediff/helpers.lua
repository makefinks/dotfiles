local M = {}

function M.require_module(module_name, error_message, opts)
	opts = opts or {}

	local ok, module = pcall(require, module_name)
	if not ok then
		if opts.notify ~= false then
			vim.notify(error_message or ("Failed to load " .. module_name), vim.log.levels.ERROR)
		end
		return nil
	end

	local required_functions = opts.functions
	if type(required_functions) == "string" then
		required_functions = { required_functions }
	end

	if required_functions and type(module) ~= "table" then
		if opts.notify ~= false then
			vim.notify(
				opts.api_error or error_message or ("Unsupported " .. module_name .. " API"),
				vim.log.levels.ERROR
			)
		end
		return nil
	end

	for _, function_name in ipairs(required_functions or {}) do
		if type(module[function_name]) ~= "function" then
			if opts.notify ~= false then
				vim.notify(
					opts.api_error or error_message or ("Unsupported " .. module_name .. " API"),
					vim.log.levels.ERROR
				)
			end
			return nil
		end
	end

	return module
end

function M.get_loaded_module(module_name)
	return package.loaded[module_name]
end

-- Emit async errors on the next scheduler tick so they don't interrupt Git callbacks.
function M.notify_error(message)
	vim.schedule(function()
		vim.notify("codediff: " .. message, vim.log.levels.ERROR)
	end)
end

function M.handle_async_error(err)
	if not err then
		return false
	end

	M.notify_error(err)
	return true
end

-- Resolve the current buffer to a repo-relative file so branch previews can reuse it.
function M.get_current_repo_file_info()
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
		abs = abs,
	}
end

-- Resolve the current working directory to a git root for project-wide entry points.
function M.get_cwd_repo()
	local repo = vim.fn.systemlist({ "git", "-C", vim.fn.getcwd(), "rev-parse", "--show-toplevel" })[1]
	if vim.v.shell_error ~= 0 or not repo or repo == "" then
		vim.notify("Current working directory is not in a git repository", vim.log.levels.ERROR)
		return nil
	end

	return repo
end

-- Pick a branch using snacks when available, otherwise fall back to plain input.
function M.with_branch(callback)
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

-- Show a file from another branch in a temporary scratch buffer.
function M.open_branch_preview(repo, rel, filetype, branch, split_mode)
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
end

-- Load the codediff modules we depend on and verify the expected API is present.
function M.get_codediff_modules()
	local codediff_git = M.require_module("codediff.core.git", nil, {
		notify = false,
		functions = "get_status",
	})
	if not codediff_git then
		M.notify_error("failed to load or validate codediff.core.git")
		return nil, nil
	end

	local view = M.require_module("codediff.ui.view", nil, {
		notify = false,
		functions = "create",
	})
	if not view then
		M.notify_error("failed to load or validate codediff.ui.view")
		return nil, nil
	end

	return codediff_git, view
end

local function filter_status_entries(entries)
	local filtered = {}

	for _, entry in ipairs(entries or {}) do
		if entry.status ~= "??" then
			filtered[#filtered + 1] = vim.deepcopy(entry)
		end
	end

	return filtered
end

function M.filter_untracked_status_result(status_result)
	if not status_result then
		return nil
	end

	return {
		unstaged = filter_status_entries(status_result.unstaged),
		staged = filter_status_entries(status_result.staged),
		conflicts = filter_status_entries(status_result.conflicts),
	}
end

return M

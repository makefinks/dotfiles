local M = {}

local large_file_threshold = 512 * 1024
local pending_large_paths = {}

local function normalize_path(path)
	if not path or path == "" then
		return nil
	end

	return vim.fn.fnamemodify(path, ":p")
end

local function resolve_path(git_root, path)
	if not path or path == "" then
		return nil
	end

	if path:sub(1, 1) == "/" then
		return normalize_path(path)
	end

	if git_root and git_root ~= "" then
		return normalize_path(git_root .. "/" .. path)
	end

	return normalize_path(path)
end

local function is_large_path(path)
	local stat = path and vim.uv.fs_stat(path) or nil
	return stat and stat.type == "file" and stat.size > large_file_threshold
end

local function is_large_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	return is_large_path(vim.api.nvim_buf_get_name(bufnr))
end

local function path_is_pending(path)
	path = normalize_path(path)
	return path and pending_large_paths[path] == true
end

function M.disable_for_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	vim.b[bufnr].codediff_lsp_disabled = true
	vim.b[bufnr].lsp_enabled = false
	vim.diagnostic.enable(false, { bufnr = bufnr })

	if vim.lsp.inlay_hint then
		pcall(vim.lsp.inlay_hint.enable, false, { bufnr = bufnr })
	end

	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		pcall(vim.lsp.buf_detach_client, bufnr, client.id)
	end

	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("noautocmd setlocal filetype=")
	end)
end

function M.prepare_selection(explorer, file_data)
	local path = resolve_path(explorer and explorer.git_root, file_data and file_data.path)
	if not is_large_path(path) then
		return
	end

	pending_large_paths[path] = true

	local existing_bufnr = vim.fn.bufnr(path)
	if existing_bufnr ~= -1 then
		M.disable_for_buffer(existing_bufnr)
	end
end

function M.apply_to_session(lifecycle, tabpage)
	if not lifecycle then
		return
	end

	local session = lifecycle.get_session(tabpage)
	if not session then
		return
	end

	for _, bufnr in ipairs({ session.original_bufnr, session.modified_bufnr, session.result_bufnr }) do
		if
			bufnr
			and vim.api.nvim_buf_is_valid(bufnr)
			and (is_large_buffer(bufnr) or path_is_pending(vim.api.nvim_buf_get_name(bufnr)))
		then
			M.disable_for_buffer(bufnr)
		end
	end
end

function M.install_autocmds(group)
	vim.api.nvim_create_autocmd({ "BufReadPre", "BufReadPost", "BufEnter", "FileType" }, {
		group = group,
		callback = function(args)
			local name = vim.api.nvim_buf_get_name(args.buf)
			if path_is_pending(name) or (vim.b[args.buf].codediff_lsp_disabled and is_large_buffer(args.buf)) then
				M.disable_for_buffer(args.buf)
			end
		end,
	})

	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(args)
			if vim.b[args.buf].codediff_lsp_disabled then
				M.disable_for_buffer(args.buf)
			end
		end,
	})
end

return M

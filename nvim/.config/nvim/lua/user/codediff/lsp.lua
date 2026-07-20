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

local function get_current_file_path(lifecycle, tabpage)
	local explorer = lifecycle and lifecycle.get_explorer(tabpage) or nil
	if not explorer then
		return nil
	end

	return resolve_path(explorer.git_root, explorer.current_file_path)
end

local function jump_within_current_diff(item, tagname, from)
	local winid = vim.api.nvim_get_current_win()
	vim.cmd("normal! m'")
	vim.fn.settagstack(winid, { items = { { tagname = tagname, from = from } } }, "t")
	vim.api.nvim_win_set_cursor(winid, { item.lnum, math.max(item.col - 1, 0) })
	vim._with({ win = winid }, function()
		vim.cmd("normal! zv")
	end)
end

local function open_outside_codediff(get_codediff_lifecycle, close_view, item)
	if not close_view(get_codediff_lifecycle) then
		return
	end

	vim.schedule(function()
		local ok = pcall(vim.cmd.edit, vim.fn.fnameescape(item.filename))
		if not ok then
			vim.notify(string.format("Failed to open %s", item.filename), vim.log.levels.ERROR)
			return
		end

		local winid = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(winid, { item.lnum, math.max(item.col - 1, 0) })
		vim._with({ win = winid }, function()
			vim.cmd("normal! zv")
		end)
	end)
end

---Jump to an LSP location without leaving a CodeDiff session for same-file targets.
---@param get_codediff_lifecycle fun(): table|nil
---@param close_view fun(get_codediff_lifecycle: fun(): table|nil): boolean
---@param method vim.lsp.protocol.Method.ClientToServer.Request
function M.jump_to_location(get_codediff_lifecycle, close_view, method)
	local bufnr = vim.api.nvim_get_current_buf()
	local winid = vim.api.nvim_get_current_win()
	local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
	if not next(clients) then
		vim.notify(vim.lsp._unsupported_method(method), vim.log.levels.WARN)
		return
	end

	local tabpage = vim.api.nvim_get_current_tabpage()
	local lifecycle = get_codediff_lifecycle()
	local current_file_path = get_current_file_path(lifecycle, tabpage)
	local from = vim.fn.getpos(".")
	from[1] = bufnr
	local tagname = vim.fn.expand("<cword>")

	vim.lsp.buf_request_all(bufnr, method, function(client)
		return vim.lsp.util.make_position_params(winid, client.offset_encoding)
	end, function(results)
		local items = {}
		for client_id, result in pairs(results) do
			local client = vim.lsp.get_client_by_id(client_id)
			if client and result and result.result then
				local locations = vim.islist(result.result) and result.result or { result.result }
				vim.list_extend(items, vim.lsp.util.locations_to_items(locations, client.offset_encoding))
			end
		end

		if #items == 0 then
			vim.notify("No locations found", vim.log.levels.INFO)
			return
		end

		if #items > 1 then
			vim.fn.setqflist({}, " ", { title = "LSP locations", items = items })
			vim.cmd("botright copen")
			return
		end

		local item = items[1]
		if current_file_path and normalize_path(item.filename) == current_file_path then
			jump_within_current_diff(item, tagname, from)
			return
		end

		open_outside_codediff(get_codediff_lifecycle, close_view, item)
	end)
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

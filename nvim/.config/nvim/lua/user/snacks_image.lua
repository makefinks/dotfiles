local M = {}

local function get_codediff_lifecycle()
	local lifecycle = package.loaded["codediff.ui.lifecycle"]
	return type(lifecycle) == "table" and lifecycle or nil
end

local function is_codediff_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local lifecycle = get_codediff_lifecycle()
	return lifecycle
		and type(lifecycle.find_tabpage_by_buffer) == "function"
		and lifecycle.find_tabpage_by_buffer(bufnr) ~= nil
end

local function clean_codediff_image_placements(snacks, bufnr)
	if not is_codediff_buffer(bufnr) then
		return
	end

	pcall(function()
		snacks.image.placement.clean(bufnr)
	end)
end

local function clean_codediff_session_buffers(snacks, tabpage)
	local lifecycle = get_codediff_lifecycle()
	if not lifecycle or type(lifecycle.get_session) ~= "function" then
		return
	end

	local session = lifecycle.get_session(tabpage)
	if not session then
		return
	end

	for _, bufnr in ipairs({ session.original_bufnr, session.modified_bufnr, session.result_bufnr }) do
		clean_codediff_image_placements(snacks, bufnr)
	end
end

local function without_codediff_images(snacks, bufnr, callback, images)
	if is_codediff_buffer(bufnr) then
		clean_codediff_image_placements(snacks, bufnr)
		return callback({})
	end

	return callback(images)
end

function M.disable_codediff_document_images(snacks)
	local ok_doc, doc = pcall(function()
		return snacks.image.doc
	end)
	if not ok_doc or type(doc) ~= "table" then
		return
	end

	if not doc._user_codediff_image_filter_installed then
		local original_attach = doc.attach
		local original_find = doc.find
		local original_find_visible = doc.find_visible

		if
			type(original_attach) == "function"
			and type(original_find) == "function"
			and type(original_find_visible) == "function"
		then
			doc.attach = function(bufnr, ...)
				if is_codediff_buffer(bufnr) then
					clean_codediff_image_placements(snacks, bufnr)
				end

				return original_attach(bufnr, ...)
			end

			doc.find = function(bufnr, callback, opts)
				return original_find(bufnr, function(images)
					return without_codediff_images(snacks, bufnr, callback, images)
				end, opts)
			end

			doc.find_visible = function(bufnr, callback, ...)
				return original_find_visible(bufnr, function(images)
					return without_codediff_images(snacks, bufnr, callback, images)
				end, ...)
			end

			doc._user_codediff_image_filter_installed = true
		end
	end

	local group = vim.api.nvim_create_augroup("user_snacks_codediff_images", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "CodeDiffOpen",
		callback = function(args)
			local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
			vim.schedule(function()
				clean_codediff_session_buffers(snacks, tabpage)
			end)
		end,
	})

	vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
		group = group,
		callback = function(args)
			local bufnr = args.buf and args.buf ~= 0 and args.buf or vim.api.nvim_get_current_buf()
			clean_codediff_image_placements(snacks, bufnr)
		end,
	})
end

return M

local M = {}

local namespace = vim.api.nvim_create_namespace("user_codediff_conflict_labels")

local function set_highlights()
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictLabel", {
		fg = "#10131A",
		bg = "#F97316",
		bold = true,
	})
	vim.api.nvim_set_hl(0, "UserCodeDiffConflictLineNr", {
		fg = "#FB923C",
		bold = true,
	})
end

local function clear_session_labels(session)
	for _, bufnr in ipairs({ session.original_bufnr, session.modified_bufnr, session.result_bufnr }) do
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
		end
	end
end

local function place_label(bufnr, line, label)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line < 0 or line >= line_count then
		return
	end

	vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
		virt_text = { { " " .. label .. " ", "UserCodeDiffConflictLabel" } },
		virt_text_pos = "right_align",
		number_hl_group = "UserCodeDiffConflictLineNr",
		priority = 300,
	})
end

local function place_result_label(session, block, tracking)
	if not session.result_bufnr or not vim.api.nvim_buf_is_valid(session.result_bufnr) or not block.extmark_id then
		return
	end

	local mark = vim.api.nvim_buf_get_extmark_by_id(session.result_bufnr, tracking.tracking_ns, block.extmark_id, {})
	if mark and #mark >= 2 then
		place_label(session.result_bufnr, mark[1], "RESOLVE HERE")
	end
end

local function render_labels(session, tracking)
	if not session or not session.conflict_blocks then
		return
	end

	clear_session_labels(session)

	for _, block in ipairs(session.conflict_blocks) do
		if tracking.is_block_active(session, block) then
			place_label(session.original_bufnr, block.output1_range.start_line - 1, "INCOMING CONFLICT")
			place_label(session.modified_bufnr, block.output2_range.start_line - 1, "CURRENT CONFLICT")
			place_result_label(session, block, tracking)
		end
	end
end

function M.install(group)
	set_highlights()

	if group then
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = group,
			callback = set_highlights,
		})
	end

	local ok_signs, signs = pcall(require, "codediff.ui.conflict.signs")
	local ok_tracking, tracking = pcall(require, "codediff.ui.conflict.tracking")
	if not ok_signs or not ok_tracking or signs._user_conflict_labels_installed then
		return
	end

	local original_refresh = signs.refresh_all_conflict_signs
	signs.refresh_all_conflict_signs = function(session, ...)
		local result = { original_refresh(session, ...) }
		render_labels(session, tracking)
		return unpack(result)
	end

	signs._user_conflict_labels_installed = true
end

return M

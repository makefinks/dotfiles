vim.opt.guicursor = table.concat({
	"n-v-c:block-Cursor/lCursor",
	"i-ci:ver25-Cursor/lCursor",
	"r-cr:hor20-Cursor/lCursor",
	"o:hor50-Cursor/lCursor",
	"a:blinkon1",
}, ",")

-- cursor color
local CUR = "#2AC3DE"

-- Define cursor highlight groups
local function set_cursor_hl()
	vim.api.nvim_set_hl(0, "Cursor", { fg = "#000000", bg = CUR })
	vim.api.nvim_set_hl(0, "lCursor", { fg = "#000000", bg = CUR })
	vim.api.nvim_set_hl(0, "TermCursor", { fg = "#000000", bg = CUR })
	vim.api.nvim_set_hl(0, "TermCursorNC", { fg = "#000000", bg = "#444444" })
end

set_cursor_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_cursor_hl })

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
	command = "if mode() != 'c' | checktime | endif",
	desc = "Check for external file changes",
})

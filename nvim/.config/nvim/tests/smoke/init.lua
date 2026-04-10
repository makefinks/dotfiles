vim.env.VSCODE_DIFF_NO_AUTO_INSTALL = "1"

vim.opt.shadafile = "NONE"
vim.opt.swapfile = false
vim.opt.termguicolors = true
vim.opt.laststatus = 0

vim.g.__agent_test = true

local cwd = vim.fn.getcwd()

vim.opt.rtp:prepend(cwd)

package.path = table.concat({
	cwd .. "/?.lua",
	cwd .. "/?/init.lua",
	cwd .. "/lua/?.lua",
	cwd .. "/lua/?/init.lua",
	cwd .. "/tests/?.lua",
	cwd .. "/tests/?/init.lua",
	cwd .. "/tests/smoke/?.lua",
	cwd .. "/tests/smoke/?/init.lua",
	package.path,
}, ";")

dofile(cwd .. "/init.lua")

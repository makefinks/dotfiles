local opt = vim.opt
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.fileencodings = { "utf-8" }
opt.updatetime = 200
opt.termguicolors = true
vim.opt.laststatus = 0
vim.o.autoread = true

-- Resolve Python provider
local function resolve_python3()
	local p = vim.fn.exepath("python3")
	if p ~= "" then
		return p
	end
	p = vim.fn.exepath("python")
	if p ~= "" then
		return p
	end
	return ""
end
local py3 = resolve_python3()
if py3 ~= "" then
	vim.g.python3_host_prog = py3
else
	vim.g.loaded_python3_provider = 0
end

-- Lazy
local lazypath = vim.env.LAZY or (vim.fn.stdpath("data") .. "/lazy/lazy.nvim")
if vim.fn.empty(vim.fn.glob(lazypath)) > 0 then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
opt.rtp:prepend(lazypath)

pcall(require, "lazy_setup")
pcall(require, "polish")

-- clipboard integration
vim.api.nvim_create_autocmd("VimEnter", {
	pattern = "*",
	group = vim.api.nvim_create_augroup("UserClipboardSetup", { clear = true }),
	callback = function()
		if vim.fn.has("clipboard") == 1 then
			vim.opt.clipboard:append("unnamedplus")
		end
	end,
	desc = "Defer clipboard setup until VimEnter",
})

pcall(require, "local")

vim.keymap.set("n", "<C-d>", "10j", { noremap = true })
vim.keymap.set("n", "<C-u>", "10k", { noremap = true })
vim.keymap.set("v", "<C-d>", "10j", { noremap = true })
vim.keymap.set("v", "<C-u>", "10k", { noremap = true })

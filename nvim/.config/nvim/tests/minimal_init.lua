vim.env.VSCODE_DIFF_NO_AUTO_INSTALL = "1"

vim.opt.shadafile = "NONE"
vim.opt.swapfile = false
vim.opt.termguicolors = true
vim.opt.laststatus = 0

vim.g.mapleader = " "
vim.g.maplocalleader = ","

local cwd = vim.fn.getcwd()
local lazy_root = vim.fn.stdpath("data") .. "/lazy"

vim.opt.rtp:prepend(cwd)

for _, plugin in ipairs({ "plenary.nvim", "codediff.nvim" }) do
  local plugin_path = lazy_root .. "/" .. plugin
  assert(vim.fn.isdirectory(plugin_path) == 1, string.format("Missing test dependency: %s", plugin_path))
  vim.opt.rtp:prepend(plugin_path)
end

package.path = table.concat({
  cwd .. "/?.lua",
  cwd .. "/?/init.lua",
  cwd .. "/lua/?.lua",
  cwd .. "/lua/?/init.lua",
  cwd .. "/tests/?.lua",
  cwd .. "/tests/?/init.lua",
  package.path,
}, ";")

vim.cmd "runtime! plugin/*.lua plugin/*.vim"

local codediff_spec = require "plugins.git.codediff"
codediff_spec.config()

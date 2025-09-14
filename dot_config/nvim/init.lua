local opt = vim.opt
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.fileencodings = { "utf-8" }
opt.fileformats = { "unix", "dos" }
opt.updatetime = 200
opt.termguicolors = true

-- Windows git bash integration (for toggleterm)
local uv = vim.uv or vim.loop
local uname = uv.os_uname()
local sysname = uname.sysname
local is_win = sysname:match "Windows" and true or false

local function first_executable(list)
  for _, exe in ipairs(list) do
    if exe and vim.fn.executable(exe) == 1 then return exe end
  end
end

if is_win then
  -- Prefer Git for Windows Bash, then pwsh, then Windows PowerShell.
  local bash = first_executable {
    vim.env.GIT_BASH, -- user override, e.g. "C:/Program Files/Git/bin/bash.exe"
    "C:/Program Files/Git/bin/bash.exe",
    "bash.exe",
  }

  if bash then
    if bash:find "%s" then bash = '"' .. bash .. '"' end
    opt.shell = bash
    opt.shellcmdflag = "-lc"
    opt.shellquote = ""
    opt.shellxquote = ""
    opt.shellslash = true
    opt.shellredir = ">%s 2>&1"
    opt.shellpipe = "2>&1 | tee %s"
  else
    local pwsh = first_executable { "pwsh.exe", "powershell.exe" }
    opt.shell = pwsh or "powershell.exe"
    opt.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy Bypass -Command"
    opt.shellquote = ""
    opt.shellxquote = ""
    opt.shellredir = "2>&1 | Out-File -Encoding UTF8 %s"
    opt.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s"
  end
else
  -- macOS and Linux (incl. WSL)
  opt.shell = vim.env.SHELL or "/bin/bash"
  opt.shellcmdflag = "-lc"
  opt.shellquote = ""
  opt.shellxquote = ""
  opt.shellredir = ">%s 2>&1"
  opt.shellpipe = "2>&1 | tee %s"
end

-- Resolve Python provider
local function resolve_python3()
  local p = vim.fn.exepath "python3"
  if p ~= "" then return p end
  p = vim.fn.exepath "python"
  if p ~= "" then return p end
  return ""
end
local py3 = resolve_python3()
if py3 ~= "" then
  vim.g.python3_host_prog = py3
else
  vim.g.loaded_python3_provider = 0
end

-- Lazy
local lazypath = vim.env.LAZY or (vim.fn.stdpath "data" .. "/lazy/lazy.nvim")
if vim.fn.empty(vim.fn.glob(lazypath)) > 0 then
  vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  }
end
opt.rtp:prepend(lazypath)

pcall(require, "lazy_setup")
pcall(require, "polish")

-- clipboard integration
vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  group = vim.api.nvim_create_augroup("UserClipboardSetup", { clear = true }),
  callback = function()
    if vim.fn.has "clipboard" == 1 then vim.opt.clipboard:append "unnamedplus" end
  end,
  desc = "Defer clipboard setup until VimEnter",
})

pcall(require, "local")

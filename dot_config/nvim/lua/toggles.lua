local M = {}

-- work / home via .env
M.profile = vim.env.NVIM_PROFILE or "home"

M.plugins = {

  -- fun
  leetcode = { home = true, work = false },
  typr = { home = true, work = false },
  smear_cursor = { home = false, work = false },

  -- ai
  opencode = { home = true, work = false },

  -- pickers
  fff = { home = true, work = true },
}

-- helper
function M.enabled(key, default_true)
  local cfg = M.plugins[key]
  if cfg == nil then return default_true ~= false end
  if type(cfg) == "boolean" then return cfg end
  local v = cfg[M.profile]
  if v == nil then return default_true ~= false end
  return v
end

return M

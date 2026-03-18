local M = {}

local function has_existing_buffer(abs_path)
  return vim.fn.bufnr(abs_path) > 0
end

local function iter_status_files(status_result)
  local files = {}

  for _, group in ipairs({ "unstaged", "staged", "conflicts" }) do
    for _, entry in ipairs((status_result or {})[group] or {}) do
      files[#files + 1] = entry
    end
  end

  return files
end

-- Resolve a reliable filetype for preloaded diff buffers before LSP startup.
local function get_buffer_filetype(bufnr, abs_path)
  local ok, filetype = pcall(vim.filetype.match, {
    buf = bufnr,
    filename = abs_path,
  })

  if ok and filetype and filetype ~= "" then
    return filetype
  end

  return nil
end

-- Collect lspconfig server definitions that advertise support for a filetype.
local function get_lsp_configs_for_filetype(filetype)
  local ok, util = pcall(require, "lspconfig.util")
  if not ok or type(util.get_config_by_ft) ~= "function" then
    return {}
  end

  local ok_configs, configs = pcall(util.get_config_by_ft, filetype)
  if not ok_configs or type(configs) ~= "table" then
    return {}
  end

  return configs
end

-- Build a dedupe key for a server/root pair so we only warm each workspace once.
local function get_lsp_root_key(config, abs_path, bufnr)
  if type(config) ~= "table" then
    return abs_path
  end

  local root_dir = config.root_dir or config.get_root_dir
  if type(root_dir) == "string" and root_dir ~= "" then
    return root_dir
  end

  if type(root_dir) == "function" then
    local ok, resolved = pcall(root_dir, abs_path, bufnr)
    if ok and type(resolved) == "string" and resolved ~= "" then
      return resolved
    end
  end

  if config.single_file_support then
    return vim.fs.dirname(abs_path)
  end

  return abs_path
end

-- Remember scratch buffers created only for LSP warmup so they can be removed on close.
local function track_preload_buffer(tabpage, bufnr, get_codediff_lifecycle)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return
  end

  local session = lifecycle.get_session(tabpage)
  if not session then
    return
  end

  session.codediff_preload_buffers = session.codediff_preload_buffers or {}
  session.codediff_preload_buffers[bufnr] = true
end

-- Preload one representative buffer per server/root so codediff opens with LSPs already attached.
function M.preload(tabpage, git_root, status_result, get_codediff_lifecycle)
  local candidates = {}
  local seen = {}

  for _, entry in ipairs(iter_status_files(status_result)) do
    local rel_path = entry.path
    if rel_path and rel_path ~= "" then
      local abs_path = git_root .. "/" .. rel_path
      if vim.fn.filereadable(abs_path) == 1 and not has_existing_buffer(abs_path) then
        local bufnr = vim.fn.bufadd(abs_path)
        if bufnr > 0 then
          vim.bo[bufnr].buflisted = false
          vim.bo[bufnr].bufhidden = "hide"
          vim.bo[bufnr].swapfile = false
          vim.fn.bufload(bufnr)

          local filetype = get_buffer_filetype(bufnr, abs_path)
          if filetype and filetype ~= "" then
            vim.bo[bufnr].filetype = filetype

            local configs = get_lsp_configs_for_filetype(filetype)
            local keep_buffer = false
            for _, config in ipairs(configs) do
              local config_name = config.name or "unknown"
              local root_key = get_lsp_root_key(config, abs_path, bufnr)
              local preload_key = table.concat({ config_name, root_key }, "::")
              if not seen[preload_key] then
                seen[preload_key] = true
                keep_buffer = true
                candidates[#candidates + 1] = {
                  bufnr = bufnr,
                  config = config,
                }
                track_preload_buffer(tabpage, bufnr, get_codediff_lifecycle)
              end
            end

            if not keep_buffer then
              pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
            end
          else
            pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
          end
        end
      end
    end
  end

  -- Launch after collection so root resolution and dedupe happen before any server startup.
  for _, candidate in ipairs(candidates) do
    pcall(candidate.config.launch, candidate.bufnr)
  end
end

-- Remove any hidden buffers that were created only to warm LSPs for the codediff tab.
function M.clear(tabpage, get_codediff_lifecycle)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return
  end

  local session = lifecycle.get_session(tabpage)
  if not session or not session.codediff_preload_buffers then
    return
  end

  for bufnr, _ in pairs(session.codediff_preload_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end

  session.codediff_preload_buffers = nil
end

return M

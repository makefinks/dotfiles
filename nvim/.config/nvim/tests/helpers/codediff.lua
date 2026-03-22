local M = {}

local function run(argv)
  local output = vim.fn.system(argv)
  local exit_code = vim.v.shell_error
  return output, exit_code
end

local function assert_ok(argv)
  local output, exit_code = run(argv)
  assert(exit_code == 0, string.format("Command failed (%s): %s", table.concat(argv, " "), output))
  return output
end

function M.get_codediff_lifecycle()
  return require "codediff.ui.lifecycle"
end

function M.wait_for(predicate, timeout_ms, message)
  local ok = vim.wait(timeout_ms or 10000, predicate, 50)
  assert(ok, message or "Timed out waiting for condition")
end

function M.create_temp_git_repo()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")

  assert_ok({ "git", "-C", dir, "init" })
  assert_ok({ "git", "-C", dir, "config", "user.email", "tests@example.com" })
  assert_ok({ "git", "-C", dir, "config", "user.name", "Tests" })
  assert_ok({ "git", "-C", dir, "branch", "-m", "main" })

  local repo_root = vim.trim(assert_ok({ "git", "-C", dir, "rev-parse", "--show-toplevel" }))
  if repo_root ~= "" then
    dir = repo_root
  end

  return {
    dir = dir,
    git = function(args)
      local argv = { "git", "-C", dir }
      vim.list_extend(argv, args)
      return run(argv)
    end,
    git_ok = function(args)
      local argv = { "git", "-C", dir }
      vim.list_extend(argv, args)
      return assert_ok(argv)
    end,
    write_file = function(rel_path, lines)
      local full_path = dir .. "/" .. rel_path
      vim.fn.mkdir(vim.fn.fnamemodify(full_path, ":h"), "p")
      vim.fn.writefile(lines, full_path)
      return full_path
    end,
    path = function(rel_path)
      return dir .. "/" .. rel_path
    end,
    cleanup = function()
      vim.fn.delete(dir, "rf")
    end,
  }
end

function M.open_status_explorer(repo, focus_file, opts)
  local lifecycle = M.get_codediff_lifecycle()
  local tabpage

  require("plugins.git.codediff.view").open_status_explorer(repo.dir, focus_file, opts or { hide_untracked = true }, M.get_codediff_lifecycle)

  M.wait_for(function()
    for _, tp in ipairs(vim.api.nvim_list_tabpages()) do
      local session = lifecycle.get_session(tp)
      local explorer = lifecycle.get_explorer(tp)
      if session and explorer and session.mode == "explorer" then
        local original_bufnr, modified_bufnr = lifecycle.get_buffers(tp)
        if original_bufnr and modified_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) and vim.api.nvim_buf_is_valid(modified_bufnr) then
          tabpage = tp
          return true
        end
      end
    end

    return false
  end, 15000, "CodeDiff explorer was not ready")

  return tabpage, lifecycle.get_session(tabpage), lifecycle.get_explorer(tabpage)
end

function M.focus_modified_window(tabpage)
  local lifecycle = M.get_codediff_lifecycle()
  local session = lifecycle.get_session(tabpage)
  assert(session and session.modified_win and vim.api.nvim_win_is_valid(session.modified_win), "Modified CodeDiff window was not ready")
  vim.api.nvim_set_current_win(session.modified_win)
  return vim.api.nvim_win_get_buf(session.modified_win)
end

function M.set_explorer_hidden(tabpage, hidden)
  local lifecycle = M.get_codediff_lifecycle()
  local explorer = lifecycle.get_explorer(tabpage)
  assert(explorer, "CodeDiff explorer missing")

  if explorer.is_hidden ~= hidden then
    require("plugins.git.codediff.view").toggle_explorer(M.get_codediff_lifecycle, tabpage)
  end

  M.wait_for(function()
    return explorer.is_hidden == hidden
  end, 5000, hidden and "CodeDiff explorer did not hide" or "CodeDiff explorer did not reopen")

  if not hidden then
    M.wait_for(function()
      local winid = explorer.split and explorer.split.winid or explorer.winid
      return winid and vim.api.nvim_win_is_valid(winid)
    end, 5000, "CodeDiff explorer window was not valid after reopen")
  end

  return explorer
end

function M.status_has_path(status_result, group, path)
  for _, entry in ipairs(status_result and status_result[group] or {}) do
    if entry.path == path then
      return true
    end
  end

  return false
end

function M.find_tree_entry(explorer, path, group)
  if not explorer or not explorer.bufnr or not vim.api.nvim_buf_is_valid(explorer.bufnr) then
    return nil
  end

  for line = 1, vim.api.nvim_buf_line_count(explorer.bufnr) do
    local node = explorer.tree:get_node(line)
    if node and node.data and node.data.path == path and node.data.group == group then
      return node
    end
  end

  return nil
end

function M.capture_echoes(opts)
  local config = opts or {}
  local original = vim.api.nvim_echo
  local calls = {}

  vim.api.nvim_echo = function(chunks, history, echo_opts)
    local parts = {}
    for _, chunk in ipairs(chunks or {}) do
      parts[#parts + 1] = chunk[1] or ""
    end

    calls[#calls + 1] = table.concat(parts)
    if config.passthrough then
      return original(chunks, history, echo_opts)
    end
  end

  return {
    calls = calls,
    contains = function(text)
      for _, call in ipairs(calls) do
        if call:find(text, 1, true) then
          return true
        end
      end

      return false
    end,
    restore = function()
      vim.api.nvim_echo = original
    end,
  }
end

function M.reset_editor()
  pcall(vim.cmd, "silent! tabonly")
  pcall(vim.cmd, "silent! %bwipeout!")
  pcall(vim.cmd, "silent! enew")
end

return M

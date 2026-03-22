local M = {}

local helpers = require "plugins.git.codediff.helpers"

local function get_explorer_winid(explorer)
  if not explorer then
    return nil
  end

  return explorer.split and explorer.split.winid or explorer.winid
end

local function disable_panel_scrollbind(winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  vim.wo[winid].scrollbind = false
  vim.wo[winid].cursorbind = false
end

local function set_explorer_options(get_codediff_lifecycle, tabpage, opts)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return
  end

  local session = lifecycle.get_session(tabpage)
  local explorer = lifecycle.get_explorer(tabpage)
  if session then
    session.hide_untracked = opts.hide_untracked or false
  end

  if explorer then
    explorer.hide_untracked = opts.hide_untracked or false
    if explorer.hide_untracked then
      explorer.status_result = helpers.filter_untracked_status_result(explorer.status_result)
    end
  end
end

-- Open the explorer view for a repo status snapshot, optionally focusing a file.
function M.open_status_explorer(repo, focus_file, opts, get_codediff_lifecycle)
  opts = opts or {}
  local codediff_git, view = helpers.get_codediff_modules()
  if not codediff_git or not view then
    return
  end

  codediff_git.get_status(repo, function(err, status_result)
    if err then
      helpers.notify_error(err)
      return
    end

    if opts.hide_untracked ~= false then
      status_result = helpers.filter_untracked_status_result(status_result)
    end

    vim.schedule(function()
      view.create({
        mode = "explorer",
        git_root = repo,
        original_path = "",
        modified_path = "",
        original_revision = nil,
        modified_revision = nil,
        explorer_data = {
          status_result = status_result,
          focus_file = focus_file,
        },
      }, "")

      local tabpage = vim.api.nvim_get_current_tabpage()
      set_explorer_options(get_codediff_lifecycle, tabpage, {
        hide_untracked = opts.hide_untracked ~= false,
      })

    end)
  end)
end

-- Close the active codediff tab without losing unsaved work.
function M.close_view(get_codediff_lifecycle)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return
  end

  local tabpage = vim.api.nvim_get_current_tabpage()
  if not lifecycle.get_session(tabpage) then
    vim.notify("Current tab is not an active codediff view", vim.log.levels.WARN)
    return
  end

  if not lifecycle.confirm_close_with_unsaved(tabpage) then
    return
  end

  if #vim.api.nvim_list_tabpages() == 1 then
    local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
    vim.cmd "tabnew"
    lifecycle.cleanup_for_quit(tabpage)
    if vim.api.nvim_tabpage_is_valid(tabpage) then
      vim.cmd(tabnr .. "tabclose")
    end
    return
  end

  vim.cmd "tabclose"
end

-- Return the explorer object for the current codediff tab, if one exists.
function M.get_explorer(get_codediff_lifecycle, tabpage)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return nil
  end

  local explorer = lifecycle.get_explorer(tabpage)
  disable_panel_scrollbind(get_explorer_winid(explorer))
  return explorer
end

function M.ensure_explorer_window_state(get_codediff_lifecycle, tabpage)
  local explorer = M.get_explorer(get_codediff_lifecycle, tabpage)
  if not explorer then
    return
  end

  disable_panel_scrollbind(get_explorer_winid(explorer))
end

function M.get_file_position(tabpage)
  tabpage = tabpage or vim.api.nvim_get_current_tabpage()

  local lifecycle = package.loaded["codediff.ui.lifecycle"]
  if not lifecycle then
    return nil
  end

  local session = lifecycle.get_session(tabpage)
  if not session or session.mode ~= "explorer" then
    return nil
  end

  local explorer = lifecycle.get_explorer(tabpage)
  if not explorer or not explorer.tree or not explorer.current_file_path or not explorer.current_file_group then
    return nil
  end

  local ok_refresh, refresh = pcall(require, "codediff.ui.explorer.refresh")
  if not ok_refresh or type(refresh.get_all_files) ~= "function" then
    return nil
  end

  local files = refresh.get_all_files(explorer.tree)
  local total = #files
  if total == 0 then
    return nil
  end

  local current_index = nil
  for i, file in ipairs(files) do
    local data = file.data
    if data and data.path == explorer.current_file_path and data.group == explorer.current_file_group then
      current_index = i
      break
    end
  end

  if not current_index then
    return nil
  end

  return string.format("%d/%d", current_index, total)
end

function M.echo_file_position(tabpage)
  local position = M.get_file_position(tabpage)
  if not position then
    return
  end

  vim.api.nvim_echo({ { string.format("%s files", position), "ModeMsg" } }, false, {})
end

-- Hide/show the explorer while keeping the active diff windows usable.
function M.toggle_explorer(get_codediff_lifecycle, tabpage)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return
  end

  local explorer = lifecycle.get_explorer(tabpage)
  if not explorer then
    vim.notify("Current tab is not an active codediff explorer", vim.log.levels.WARN)
    return
  end

  local ok, explorer_ui = pcall(require, "codediff.ui.explorer")
  if not ok then
    vim.notify("Failed to load codediff explorer", vim.log.levels.ERROR)
    return
  end

  local explorer_win = explorer.split and explorer.split.winid or explorer.winid
  local is_hidden = explorer.is_hidden

  if not is_hidden and explorer_win and vim.api.nvim_win_is_valid(explorer_win) and vim.api.nvim_get_current_win() == explorer_win then
    local session = lifecycle.get_session(tabpage)
    local fallback_win = session and (session.modified_win or session.original_win) or nil
    if fallback_win and vim.api.nvim_win_is_valid(fallback_win) then
      vim.api.nvim_set_current_win(fallback_win)
    end
  end

  explorer_ui.toggle_visibility(explorer)

  if is_hidden then
    vim.schedule(function()
      local winid = explorer.split and explorer.split.winid or explorer.winid
      if winid and vim.api.nvim_win_is_valid(winid) then
        disable_panel_scrollbind(winid)
        vim.api.nvim_set_current_win(winid)
      end
    end)
  end
end

-- Refocus the diff pane after opening a file from the explorer.
function M.focus_diff_window(get_codediff_lifecycle, tabpage)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle or type(lifecycle.get_windows) ~= "function" then
    return false
  end

  local original_win, modified_win = lifecycle.get_windows(tabpage)
  local target_win = modified_win

  if not target_win or not vim.api.nvim_win_is_valid(target_win) then
    target_win = original_win
  end

  if not target_win or not vim.api.nvim_win_is_valid(target_win) then
    return false
  end

  vim.api.nvim_set_current_win(target_win)
  return true
end

function M.select_explorer_file(get_codediff_lifecycle, tabpage, explorer, file_data)
  if not explorer or not file_data then
    return
  end

  disable_panel_scrollbind(get_explorer_winid(explorer))
  explorer.on_file_select(file_data)
  vim.schedule(function()
    disable_panel_scrollbind(get_explorer_winid(explorer))
  end)
end

-- Open the selected explorer node, or expand/collapse groups and directories.
function M.open_explorer_entry(get_codediff_lifecycle, tabpage, explorer)
  if not explorer or not explorer.tree then
    return
  end

  local node = explorer.tree:get_node()
  if not node then
    return
  end

  if node.data and (node.data.type == "group" or node.data.type == "directory") then
    if node:is_expanded() then
      node:collapse()
    else
      node:expand()
    end
    explorer.tree:render()
    return
  end

  if not node.data then
    return
  end

  local same_selection = explorer.current_file_path == node.data.path and explorer.current_file_group == node.data.group
  if not same_selection then
    M.select_explorer_file(get_codediff_lifecycle, tabpage, explorer, node.data)
  end

  vim.schedule(function()
    M.focus_diff_window(get_codediff_lifecycle, tabpage)
  end)
end

function M.install_refresh_filter()
  local ok_refresh, refresh = pcall(require, "codediff.ui.explorer.refresh")
  if not ok_refresh or refresh._user_hide_untracked_installed then
    return
  end

  local original_refresh = refresh.refresh
  refresh.refresh = function(explorer, ...)
    if not explorer or not explorer.hide_untracked then
      return original_refresh(explorer, ...)
    end

    local ok_git, git = pcall(require, "codediff.core.git")
    if not ok_git or type(git.get_status) ~= "function" then
      return original_refresh(explorer, ...)
    end

    local original_get_status = git.get_status
    git.get_status = function(git_root, callback)
      return original_get_status(git_root, function(err, status_result)
        callback(err, helpers.filter_untracked_status_result(status_result))
      end)
    end

    local ok, result = pcall(original_refresh, explorer, ...)
    git.get_status = original_get_status
    if not ok then
      error(result)
    end

    return result
  end

  refresh._user_hide_untracked_installed = true
end

return M

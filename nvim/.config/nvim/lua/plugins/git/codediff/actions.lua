local M = {}

local view = require "plugins.git.codediff.view"

local function find_current_selection(explorer, file_path, group)
  if explorer.current_selection and explorer.current_selection.path == file_path and explorer.current_selection.group == group then
    return vim.deepcopy(explorer.current_selection)
  end

  local group_entries = explorer.status_result and explorer.status_result[group] or nil
  for _, entry in ipairs(group_entries or {}) do
    if entry.path == file_path then
      local selection = vim.deepcopy(entry)
      selection.group = group
      return selection
    end
  end

  return nil
end

local function get_next_file_in_group(explorer, current_path, target_group)
  local ok, refresh = pcall(require, "codediff.ui.explorer.refresh")
  if not ok then
    return nil
  end

  local files = {}
  for _, entry in ipairs(refresh.get_all_files(explorer.tree)) do
    if entry.data and entry.data.group == target_group and entry.data.path then
      files[#files + 1] = entry.data
    end
  end

  if #files == 0 then
    return nil
  end

  local current_index = nil
  for i, entry in ipairs(files) do
    if entry.path == current_path then
      current_index = i
      break
    end
  end

  if not current_index then
    return vim.deepcopy(files[1])
  end

  if #files == 1 then
    return nil
  end

  local next_index = current_index % #files + 1
  return vim.deepcopy(files[next_index])
end

local function refresh_after_group_action(explorer, next_file, next_group)
  local ok_refresh, refresh = pcall(require, "codediff.ui.explorer.refresh")
  if not ok_refresh then
    vim.notify("Failed to refresh codediff explorer", vim.log.levels.ERROR)
    return
  end

  if next_file then
    explorer.current_file_path = next_file.path
    explorer.current_file_group = next_group
    explorer.current_selection = vim.deepcopy(next_file)
  else
    explorer.current_file_path = nil
    explorer.current_file_group = nil
    explorer.current_selection = nil
    if explorer.clear_selection then
      explorer.clear_selection()
    end

    local ok_render, render = pcall(require, "codediff.ui.explorer.render")
    if ok_render then
      render.show_welcome_page(explorer)
    end
  end

  refresh.refresh(explorer)
end

-- Collect the explorer/file context needed for stage and unstage actions.
local function get_stage_context(get_codediff_lifecycle, tabpage)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return nil
  end

  local explorer = lifecycle.get_explorer(tabpage)
  local session = lifecycle.get_session(tabpage)
  if not session then
    return nil
  end

  if session.mode ~= "explorer" then
    vim.notify("Stage/unstage only available in codediff explorer mode", vim.log.levels.WARN)
    return nil
  end

  if not explorer or not explorer.git_root then
    vim.notify("Stage/unstage only available in git mode", vim.log.levels.WARN)
    return nil
  end

  local ok_explorer, explorer_ui = pcall(require, "codediff.ui.explorer")
  if not ok_explorer then
    vim.notify("Failed to load codediff explorer", vim.log.levels.ERROR)
    return nil
  end

  local ok_git, git = pcall(require, "codediff.core.git")
  if not ok_git then
    vim.notify("Failed to load codediff git helpers", vim.log.levels.ERROR)
    return nil
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
  local file_path
  local group
  local is_directory = false
  local directory_path

  if explorer.bufnr and current_buf == explorer.bufnr then
    local node = explorer.tree and explorer.tree:get_node() or nil
    if not node or not node.data or node.data.type == "group" then
      return nil
    end

    if node.data.type == "directory" then
      is_directory = true
      directory_path = node.data.dir_path
    else
      file_path = node.data.path
    end
    group = node.data.group
  elseif current_buf == original_bufnr or current_buf == modified_bufnr then
    file_path = explorer.current_file_path
    group = explorer.current_file_group
  else
    return nil
  end

  return {
    explorer = explorer,
    explorer_ui = explorer_ui,
    git = git,
    current_buf = current_buf,
    file_path = file_path,
    directory_path = directory_path,
    group = group,
    is_directory = is_directory,
    in_explorer = explorer.bufnr and current_buf == explorer.bufnr,
  }
end

local function get_restore_context(get_codediff_lifecycle, tabpage)
  local context = get_stage_context(get_codediff_lifecycle, tabpage)
  if not context then
    return nil
  end

  if context.in_explorer then
    return context
  end

  if context.is_directory or not context.file_path or not context.group then
    return nil
  end

  local selection = find_current_selection(context.explorer, context.file_path, context.group)
  if not selection then
    return nil
  end

  context.status = selection.status
  return context
end

-- Stage the current file or directory and advance selection when possible.
function M.stage_entry(get_codediff_lifecycle, tabpage)
  local context = get_stage_context(get_codediff_lifecycle, tabpage)
  if not context then
    return
  end

  if context.is_directory then
    if context.group == "unstaged" or context.group == "conflicts" then
      context.explorer_ui.toggle_stage_entry(context.explorer, context.explorer.tree)
    else
      vim.notify("Current entry is already staged", vim.log.levels.WARN)
    end
    return
  end

  if not context.file_path or not context.group then
    return
  end

  if context.group == "staged" then
    vim.notify("Current entry is already staged", vim.log.levels.WARN)
    return
  end

  if context.group ~= "unstaged" and context.group ~= "conflicts" then
    return
  end

  local next_group = context.group
  local next_file = get_next_file_in_group(context.explorer, context.file_path, next_group)
  context.git.stage_file(context.explorer.git_root, context.file_path, function(err)
    if err then
      vim.schedule(function()
        vim.notify(err, vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      refresh_after_group_action(context.explorer, next_file, next_group)
    end)
  end)
end

-- Unstage the current file or directory and advance selection when possible.
function M.unstage_entry(get_codediff_lifecycle, tabpage)
  local context = get_stage_context(get_codediff_lifecycle, tabpage)
  if not context then
    return
  end

  if context.is_directory then
    if context.group == "staged" then
      context.explorer_ui.toggle_stage_entry(context.explorer, context.explorer.tree)
    else
      vim.notify("Current entry is not staged", vim.log.levels.WARN)
    end
    return
  end

  if not context.file_path or not context.group then
    return
  end

  if context.group ~= "staged" then
    vim.notify("Current entry is not staged", vim.log.levels.WARN)
    return
  end

  local next_group = "staged"
  local next_file = get_next_file_in_group(context.explorer, context.file_path, next_group)
  context.git.unstage_file(context.explorer.git_root, context.file_path, function(err)
    if err then
      vim.schedule(function()
        vim.notify(err, vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      refresh_after_group_action(context.explorer, next_file, next_group)
    end)
  end)
end

-- Toggle between staged and unstaged state based on the current file group.
function M.toggle_stage(get_codediff_lifecycle, tabpage)
  local context = get_stage_context(get_codediff_lifecycle, tabpage)
  if not context then
    return
  end

  if context.group == "staged" then
    M.unstage_entry(get_codediff_lifecycle, tabpage)
    return
  end

  M.stage_entry(get_codediff_lifecycle, tabpage)
end

-- Discard the current file changes through the explorer's restore action.
function M.restore_entry(get_codediff_lifecycle, tabpage)
  local context = get_restore_context(get_codediff_lifecycle, tabpage)
  if not context then
    vim.notify("Discard is only available in codediff explorer mode", vim.log.levels.WARN)
    return
  end

  local ok, action_mod = pcall(require, "codediff.ui.explorer.actions")
  if not ok then
    vim.notify("Failed to load codediff explorer actions", vim.log.levels.ERROR)
    return
  end

  if context.in_explorer then
    action_mod.restore_entry(context.explorer, context.explorer.tree)
    return
  end

  local ok_git, git = pcall(require, "codediff.core.git")
  local ok_refresh, refresh = pcall(require, "codediff.ui.explorer.refresh")
  if not ok_git or not ok_refresh then
    vim.notify("Failed to load codediff discard helpers", vim.log.levels.ERROR)
    return
  end

  if context.group ~= "unstaged" then
    vim.notify("Can only restore unstaged changes", vim.log.levels.WARN)
    return
  end

  local is_untracked = context.status == "??"
  local prompt = (is_untracked and "Delete " or "Discard changes to ") .. context.file_path .. "?"
  local choice = vim.fn.confirm(prompt, "&Discard\n&Cancel", 2, "Warning")
  if choice ~= 1 then
    vim.cmd "echo ''"
    return
  end

  local after_restore = function(err)
    if err then
      vim.schedule(function()
        vim.notify(err, vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      refresh.refresh(context.explorer)
    end)
  end

  if is_untracked then
    git.delete_untracked(context.explorer.git_root, context.file_path, after_restore)
  else
    git.restore_file(context.explorer.git_root, context.file_path, context.explorer.base_revision, after_restore)
  end

  vim.cmd "echo ''"
end

-- Open a file picker over all explorer entries for faster jump navigation.
function M.open_file_picker(get_codediff_lifecycle, tabpage)
  local explorer = view.get_explorer(get_codediff_lifecycle, tabpage)
  if not explorer or not explorer.status_result then
    vim.notify("Current tab is not an active codediff explorer", vim.log.levels.WARN)
    return
  end

  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua is required for the codediff picker", vim.log.levels.ERROR)
    return
  end

  local fzf_utils = require "fzf-lua.utils"
  local entries = {}
  local entry_by_index = {}

  local groups = {
    { key = "conflicts", label = "merge", files = explorer.status_result.conflicts or {} },
    { key = "unstaged", label = "changes", files = explorer.status_result.unstaged or {} },
    { key = "staged", label = "staged", files = explorer.status_result.staged or {} },
  }

  local index = 0
  for _, group in ipairs(groups) do
    for _, file in ipairs(group.files) do
      index = index + 1

      local details = string.format("[%s]", file.status or " ")
      if file.old_path and file.old_path ~= "" and file.old_path ~= file.path then
        details = string.format("%s %s", details, file.old_path)
      end

      local group_label = ({
        conflicts = fzf_utils.ansi_codes.red(group.label),
        unstaged = fzf_utils.ansi_codes.yellow(group.label),
        staged = fzf_utils.ansi_codes.blue(group.label),
      })[group.key] or group.label

      local label = string.format("%d\t%s\t%s\t%s", index, file.path, group_label, details)
      entries[#entries + 1] = label
      entry_by_index[index] = {
        path = file.path,
        old_path = file.old_path,
        status = file.status,
        git_root = explorer.git_root,
        group = group.key,
      }
    end
  end

  if #entries == 0 then
    vim.notify("No files in the current codediff view", vim.log.levels.WARN)
    return
  end

  fzf.fzf_exec(entries, {
    prompt = "CodeDiff Files> ",
    winopts = {
      title = " CodeDiff Files ",
    },
    fzf_opts = {
      ["--delimiter"] = "\t",
      ["--with-nth"] = "2,3,4",
    },
    previewer = false,
    actions = {
      ["enter"] = function(selected)
        local choice = selected and selected[1]
        local selected_index = choice and tonumber(choice:match("^%s*(%d+)\t"))
        local file = selected_index and entry_by_index[selected_index] or nil
        if not file then
          return
        end

        vim.schedule(function()
          view.select_explorer_file(get_codediff_lifecycle, tabpage, explorer, file)
        end)
      end,
    },
    fn_selected = function(selected, opts)
      local action = selected and selected[1]
      if action == "enter" and opts and opts.actions and opts.actions.enter then
        opts.actions.enter(vim.list_slice(selected, 2), opts)
      end
    end,
  })
end

return M

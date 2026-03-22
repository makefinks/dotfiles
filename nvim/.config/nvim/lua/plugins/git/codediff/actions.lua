local M = {}

local helpers = require "plugins.git.codediff.helpers"
local view = require "plugins.git.codediff.view"

local function normalize_repo_relative_path(git_root, path)
  if not git_root or not path or path == "" then
    return nil
  end

  local normalized_root = git_root:gsub("\\", "/")
  local normalized_path = path:gsub("\\", "/")

  if normalized_path:sub(1, #normalized_root + 1) == normalized_root .. "/" then
    return normalized_path:sub(#normalized_root + 2)
  end

  return normalized_path
end

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

local function find_selection_by_path(explorer, file_path)
  if not explorer or not file_path then
    return nil
  end

  for _, group in ipairs({ "conflicts", "unstaged", "staged" }) do
    local selection = find_current_selection(explorer, file_path, group)
    if selection then
      return selection
    end
  end

  return nil
end

local function get_next_file_in_group(explorer, current_path, target_group)
  if not explorer or not target_group then
    return nil
  end

  local files = explorer.status_result and explorer.status_result[target_group] or nil

  if not files or #files == 0 then
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
    return vim.deepcopy(vim.tbl_extend("force", files[1], { group = target_group }))
  end

  if #files == 1 then
    return nil
  end

  local next_index = current_index % #files + 1
  return vim.deepcopy(vim.tbl_extend("force", files[next_index], { group = target_group }))
end

local function filter_status_result(explorer, status_result)
  if not explorer or not explorer.hide_untracked then
    return status_result
  end

  return helpers.filter_untracked_status_result(status_result)
end

local function find_status_entry(status_result, file_path, preferred_group)
  if not status_result or not file_path then
    return nil
  end

  local search_order = {}
  if preferred_group then
    search_order[#search_order + 1] = preferred_group
  end

  for _, group in ipairs({ "conflicts", "unstaged", "staged" }) do
    if group ~= preferred_group then
      search_order[#search_order + 1] = group
    end
  end

  for _, group in ipairs(search_order) do
    for _, entry in ipairs(status_result[group] or {}) do
      if entry.path == file_path then
        return vim.deepcopy(vim.tbl_extend("force", entry, { group = group }))
      end
    end
  end

  return nil
end

local function rebuild_hidden_tree(explorer, status_result)
  if not explorer or not explorer.tree then
    return false
  end

  local ok_tree, tree_module = pcall(require, "codediff.ui.explorer.tree")
  local ok_config, config = pcall(require, "codediff.config")
  if not ok_tree or not ok_config then
    vim.notify("Failed to rebuild codediff explorer state", vim.log.levels.ERROR)
    return false
  end

  local root_nodes = tree_module.create_tree_data(status_result, explorer.git_root, explorer.base_revision, not explorer.git_root, explorer.visible_groups)
  for _, node in ipairs(root_nodes) do
    if node.data and node.data.type == "group" then
      node:expand()
    end
  end

  local explorer_config = config.options.explorer or {}
  if explorer_config.view_mode == "tree" then
    local function expand_all_dirs(parent_node)
      if not parent_node:has_children() then
        return
      end

      for _, child_id in ipairs(parent_node:get_child_ids()) do
        local child = explorer.tree:get_node(child_id)
        if child and child.data and child.data.type == "directory" then
          child:expand()
          expand_all_dirs(child)
        end
      end
    end

    explorer.tree:set_nodes(root_nodes)
    for _, node in ipairs(root_nodes) do
      expand_all_dirs(node)
    end
  else
    explorer.tree:set_nodes(root_nodes)
  end

  explorer.tree:render()
  return true
end

local function refresh_hidden_explorer(explorer, next_file, next_group)
  local ok_git, git = pcall(require, "codediff.core.git")
  if not ok_git then
    vim.notify("Failed to refresh codediff explorer", vim.log.levels.ERROR)
    return
  end

  git.get_status(explorer.git_root, function(err, status_result)
    if err then
      vim.schedule(function()
        vim.notify(err, vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      local filtered_status_result = filter_status_result(explorer, status_result)
      explorer.status_result = filtered_status_result
      if not rebuild_hidden_tree(explorer, filtered_status_result) then
        return
      end

      local updated_next_file = next_file and find_status_entry(filtered_status_result, next_file.path, next_group) or nil
      if updated_next_file and explorer.on_file_select then
        explorer.on_file_select(updated_next_file, { force = true, no_jump = true })
        return
      end

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
    end)
  end)
end

local function refresh_after_group_action(explorer, next_file, next_group)
  if explorer and explorer.is_hidden then
    refresh_hidden_explorer(explorer, next_file, next_group)
    return
  end

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
    local original_path, modified_path = lifecycle.get_paths(tabpage)
    local preferred_path = modified_path

    if current_buf == original_bufnr and (not preferred_path or preferred_path == "") then
      preferred_path = original_path
    elseif not preferred_path or preferred_path == "" then
      preferred_path = original_path
    end

    file_path = normalize_repo_relative_path(explorer.git_root, preferred_path)

    local selection = find_selection_by_path(explorer, file_path)
    if not selection and explorer.current_file_path and explorer.current_file_group then
      selection = find_current_selection(explorer, explorer.current_file_path, explorer.current_file_group)
    end

    if selection then
      file_path = selection.path
      group = selection.group
    end
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
      if context.explorer and context.explorer.is_hidden then
        refresh_hidden_explorer(context.explorer)
        return
      end

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

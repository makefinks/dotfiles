-- Emit async errors on the next scheduler tick so they don't interrupt Git callbacks.
local function notify_codediff_error(message)
  vim.schedule(function()
    vim.notify("codediff: " .. message, vim.log.levels.ERROR)
  end)
end

local get_codediff_lifecycle

-- Resolve the current buffer to a repo-relative file so branch previews can reuse it.
local function get_current_repo_file_info()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("Current buffer is not a file", vim.log.levels.WARN)
    return nil
  end

  local repo = vim.fn.systemlist { "git", "-C", vim.fn.fnamemodify(file, ":h"), "rev-parse", "--show-toplevel" }[1]
  if vim.v.shell_error ~= 0 or not repo or repo == "" then
    vim.notify("File is not in a git repository", vim.log.levels.ERROR)
    return nil
  end

  local abs = vim.fn.fnamemodify(file, ":p")
  if not vim.startswith(abs, repo .. "/") then
    vim.notify("Could not resolve file path relative to repository", vim.log.levels.ERROR)
    return nil
  end

  return {
    repo = repo,
    rel = abs:sub(#repo + 2),
    filetype = vim.bo.filetype,
    abs = abs,
  }
end

-- Resolve the current working directory to a git root for project-wide entry points.
local function get_cwd_repo()
  local repo = vim.fn.systemlist { "git", "-C", vim.fn.getcwd(), "rev-parse", "--show-toplevel" }[1]
  if vim.v.shell_error ~= 0 or not repo or repo == "" then
    vim.notify("Current working directory is not in a git repository", vim.log.levels.ERROR)
    return nil
  end

  return repo
end

-- Pick a branch using snacks when available, otherwise fall back to plain input.
local function with_branch(callback)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.picker and snacks.picker.pick then
    snacks.picker.pick("git_branches", {
      title = "Git Branches",
      confirm = function(picker, item)
        picker:close()
        local branch = item and item.branch
        if not branch or branch == "" then
          vim.notify("No branch selected", vim.log.levels.WARN)
          return
        end
        callback(branch)
      end,
    })
    return
  end

  local branch = vim.fn.input("Branch: ", "main")
  if branch ~= "" then
    callback(branch)
  end
end

-- Show a file from another branch in a temporary scratch buffer.
local function open_branch_preview(repo, rel, filetype, branch, split_mode)
  local spec = branch .. ":" .. rel
  local content = vim.fn.systemlist { "git", "-C", repo, "show", spec }
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to open " .. spec, vim.log.levels.ERROR)
    return
  end

  if split_mode then
    vim.cmd "vsplit"
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].filetype = filetype
  vim.bo[buf].readonly = true
  vim.bo[buf].modifiable = false

  local ns = vim.api.nvim_create_namespace "branch_preview"
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_lines = {
      {
        { string.format(" [BRANCH PREVIEW] %s:%s  (q to close) ", branch, rel), "WarningMsg" },
      },
    },
    virt_lines_above = true,
  })

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end, { buffer = buf, silent = true, desc = "Close branch preview buffer" })
end

-- Load the codediff modules we depend on and verify the expected API is present.
local function get_codediff_modules()
  local ok_git, codediff_git = pcall(require, "codediff.core.git")
  if not ok_git then
    notify_codediff_error("failed to load codediff.core.git (" .. tostring(codediff_git) .. ")")
    return nil, nil
  end

  local ok_view, view = pcall(require, "codediff.ui.view")
  if not ok_view then
    notify_codediff_error("failed to load codediff.ui.view (" .. tostring(view) .. ")")
    return nil, nil
  end

  if type(codediff_git.get_status) ~= "function" or type(view.create) ~= "function" then
    notify_codediff_error("unsupported codediff.nvim API")
    return nil, nil
  end

  return codediff_git, view
end

local function filter_status_entries(entries)
  local filtered = {}

  for _, entry in ipairs(entries or {}) do
    if entry.status ~= "??" then
      filtered[#filtered + 1] = vim.deepcopy(entry)
    end
  end

  return filtered
end

local function filter_untracked_status_result(status_result)
  if not status_result then
    return nil
  end

  return {
    unstaged = filter_status_entries(status_result.unstaged),
    staged = filter_status_entries(status_result.staged),
    conflicts = filter_status_entries(status_result.conflicts),
  }
end

local function set_codediff_explorer_options(tabpage, opts)
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
      explorer.status_result = filter_untracked_status_result(explorer.status_result)
    end
  end
end

-- Open the explorer view for a repo status snapshot, optionally focusing a file.
local function open_codediff_status_explorer(repo, focus_file, opts)
  opts = opts or {}
  local codediff_git, view = get_codediff_modules()
  if not codediff_git or not view then
    return
  end

  codediff_git.get_status(repo, function(err, status_result)
    if err then
      notify_codediff_error(err)
      return
    end

    if opts.hide_untracked ~= false then
      status_result = filter_untracked_status_result(status_result)
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

      set_codediff_explorer_options(vim.api.nvim_get_current_tabpage(), {
        hide_untracked = opts.hide_untracked ~= false,
      })
    end)
  end)
end

-- Safely access the active codediff lifecycle module.
get_codediff_lifecycle = function()
  local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
  if not ok then
    vim.notify("Codediff is not available", vim.log.levels.ERROR)
    return nil
  end

  return lifecycle
end

-- Check whether a buffer should have markview disabled inside codediff.
local function is_markview_filetype(bufnr)
  return ({
    markdown = true,
    quarto = true,
    rmd = true,
  })[vim.bo[bufnr].filetype] == true
end

-- Temporarily disable markview in diff buffers so rendered markdown stays stable.
local function disable_markview_in_codediff(tabpage)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return
  end

  local session = lifecycle.get_session(tabpage)
  if not session then
    return
  end

  local ok_state, markview_state = pcall(require, "markview.state")
  local ok_commands, markview = pcall(require, "markview.commands")
  if not ok_state or not ok_commands then
    return
  end

  session.codediff_markview_state = session.codediff_markview_state or {}

  for _, bufnr in ipairs({ session.original_bufnr, session.modified_bufnr, session.result_bufnr }) do
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) and is_markview_filetype(bufnr) and not session.codediff_markview_state[bufnr] then
      local state = markview_state.get_buffer_state(bufnr, false)
      session.codediff_markview_state[bufnr] = {
        attached = markview_state.buf_attached(bufnr),
        enabled = state and state.enable == true or false,
      }
      markview.disable(bufnr)
    end
  end
end

-- Restore any markview-enabled buffers when the codediff tab closes.
local function restore_markview_after_codediff(tabpage)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return
  end

  local session = lifecycle.get_session(tabpage)
  if not session or not session.codediff_markview_state then
    return
  end

  local ok_commands, markview = pcall(require, "markview.commands")
  if not ok_commands then
    return
  end

  for bufnr, saved in pairs(session.codediff_markview_state) do
    if saved.attached and saved.enabled and vim.api.nvim_buf_is_valid(bufnr) then
      markview.enable(bufnr)
    end
  end

  session.codediff_markview_state = nil
end

-- Close the active codediff tab without losing unsaved work.
local function close_codediff_view()
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
local function get_codediff_explorer(tabpage)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return nil
  end

  return lifecycle.get_explorer(tabpage)
end

-- Hide/show the explorer while keeping the active diff windows usable.
local function toggle_codediff_explorer(tabpage)
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
        vim.api.nvim_set_current_win(winid)
      end
    end)
  end
end

-- Refocus the diff pane after opening a file from the explorer.
local function focus_codediff_diff_window(tabpage)
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

-- Open the selected explorer node, or expand/collapse groups and directories.
local function open_codediff_explorer_entry(tabpage, explorer)
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
    explorer.on_file_select(node.data)
  end

  vim.schedule(function()
    focus_codediff_diff_window(tabpage)
  end)
end

-- Find the next file in a status group, respecting the current selection order.
local function get_next_codediff_file_in_group(explorer, current_path, target_group)
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

-- Refresh the explorer after staging/unstaging while keeping selection state coherent.
local function refresh_codediff_after_group_action(explorer, next_file, next_group)
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
local function get_codediff_stage_context(tabpage)
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

-- Stage the current file or directory and advance selection when possible.
local function stage_codediff_entry(tabpage)
  local context = get_codediff_stage_context(tabpage)
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
  local next_file = get_next_codediff_file_in_group(context.explorer, context.file_path, next_group)
  context.git.stage_file(context.explorer.git_root, context.file_path, function(err)
    if err then
      vim.schedule(function()
        vim.notify(err, vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      refresh_codediff_after_group_action(context.explorer, next_file, next_group)
    end)
  end)
end

-- Unstage the current file or directory and advance selection when possible.
local function unstage_codediff_entry(tabpage)
  local context = get_codediff_stage_context(tabpage)
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
  local next_file = get_next_codediff_file_in_group(context.explorer, context.file_path, next_group)
  context.git.unstage_file(context.explorer.git_root, context.file_path, function(err)
    if err then
      vim.schedule(function()
        vim.notify(err, vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      refresh_codediff_after_group_action(context.explorer, next_file, next_group)
    end)
  end)
end

-- Toggle between staged and unstaged state based on the current file group.
local function toggle_codediff_stage(tabpage)
  local context = get_codediff_stage_context(tabpage)
  if not context then
    return
  end

  if context.group == "staged" then
    unstage_codediff_entry(tabpage)
    return
  end

  stage_codediff_entry(tabpage)
end

-- Discard the current file changes through the explorer's restore action.
local function restore_codediff_entry(tabpage)
  local explorer = get_codediff_explorer(tabpage)
  if not explorer or not explorer.tree then
    vim.notify("Discard is only available in codediff explorer mode", vim.log.levels.WARN)
    return
  end

  local ok, actions = pcall(require, "codediff.ui.explorer.actions")
  if not ok then
    vim.notify("Failed to load codediff explorer actions", vim.log.levels.ERROR)
    return
  end

  actions.restore_entry(explorer, explorer.tree)
end

-- Open a file picker over all explorer entries for faster jump navigation.
local function open_codediff_file_picker(tabpage)
  local explorer = get_codediff_explorer(tabpage)
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
          explorer.on_file_select(file)
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

local function install_codediff_refresh_filter()
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
        callback(err, filter_untracked_status_result(status_result))
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

return {
  "esmuellert/codediff.nvim",
  cmd = { "CodeDiff" },
  keys = {
    {
      "<leader>gd",
      function()
        local context = get_current_repo_file_info()
        if not context then
          return
        end

        open_codediff_status_explorer(context.repo, context.rel, { hide_untracked = true })
      end,
      desc = "Current file diff",
    },
    {
      "<leader>gD",
      function()
        local repo = get_cwd_repo()
        if not repo then
          return
        end

        open_codediff_status_explorer(repo, nil, { hide_untracked = true })
      end,
      desc = "Project diff",
    },
    {
      "<leader>gU",
      function()
        local repo = get_cwd_repo()
        if not repo then
          return
        end

        open_codediff_status_explorer(repo, nil, { hide_untracked = false })
      end,
      desc = "Project diff (with untracked)",
    },
    {
      "<leader>gq",
      close_codediff_view,
      desc = "Close codediff",
    },
    {
      "<leader>gF",
      function()
        local context = get_current_repo_file_info()
        if not context then
          return
        end

        vim.ui.select({ "Diff view", "Open branch file", "Open branch file (split)" }, { prompt = "View mode:" }, function(mode)
          if not mode then
            return
          end

          with_branch(function(branch)
            if mode == "Diff view" then
              vim.cmd("CodeDiff file " .. vim.fn.fnameescape(branch))
              return
            end

            local split_mode = mode == "Open branch file (split)"
            open_branch_preview(context.repo, context.rel, context.filetype, branch, split_mode)
          end)
        end)
      end,
      desc = "File in another branch",
    },
  },
  config = function()
    install_codediff_refresh_filter()

    local codediff_group = vim.api.nvim_create_augroup("user_codediff", { clear = true })
    local custom_codediff_keymaps = { "<CR>", "<Tab>", "<S-Tab>", "ff", "<leader>e", "<leader>gs", "<leader>gx", "s", "u", "x" }

    local function set_custom_codediff_keymaps(tabpage)
      local lifecycle = get_codediff_lifecycle()
      local session = lifecycle and lifecycle.get_session(tabpage) or nil
      if not lifecycle or not session then
        return
      end

      disable_markview_in_codediff(tabpage)

      lifecycle.set_tab_keymap(tabpage, "n", "ff", function()
        open_codediff_file_picker(tabpage)
      end, { desc = "Search files in codediff" })

      lifecycle.set_tab_keymap(tabpage, "n", "<leader>e", function()
        toggle_codediff_explorer(tabpage)
      end, { desc = "Toggle codediff explorer" })

      lifecycle.set_tab_keymap(tabpage, "n", "<leader>gs", function()
        toggle_codediff_stage(tabpage)
      end, { desc = "Stage/unstage current entry" })

      lifecycle.set_tab_keymap(tabpage, "n", "<leader>gx", function()
        restore_codediff_entry(tabpage)
      end, { desc = "Discard current entry" })

      local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
      for _, bufnr in ipairs({ original_bufnr, modified_bufnr }) do
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
          session.keymap_buffers = session.keymap_buffers or {}
          session.keymap_buffers[bufnr] = true

          vim.keymap.set("n", "s", function()
            stage_codediff_entry(tabpage)
          end, { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = "Stage current entry" })

          vim.keymap.set("n", "u", function()
            unstage_codediff_entry(tabpage)
          end, { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = "Unstage current entry" })

          vim.keymap.set("n", "x", function()
            restore_codediff_entry(tabpage)
          end, { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = "Discard current entry" })

          vim.keymap.set("n", "<leader>gs", function()
            toggle_codediff_stage(tabpage)
          end, { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = "Stage/unstage current entry" })
        end
      end

      local explorer = lifecycle.get_explorer(tabpage)
      if explorer then
        explorer.hide_untracked = session.hide_untracked or false
      end
      if explorer and explorer.bufnr and vim.api.nvim_buf_is_valid(explorer.bufnr) then
        local ok_navigation, navigation = pcall(require, "codediff.ui.view.navigation")
        session.keymap_buffers = session.keymap_buffers or {}
        session.keymap_buffers[explorer.bufnr] = true

        vim.keymap.set("n", "<CR>", function()
          open_codediff_explorer_entry(tabpage, explorer)
        end, { buffer = explorer.bufnr, noremap = true, silent = true, nowait = true, desc = "Open current codediff entry" })

        if ok_navigation then
          vim.keymap.set("n", "<Tab>", function()
            navigation.next_file()
          end, { buffer = explorer.bufnr, noremap = true, silent = true, nowait = true, desc = "Next codediff file" })

          vim.keymap.set("n", "<S-Tab>", function()
            navigation.prev_file()
          end, { buffer = explorer.bufnr, noremap = true, silent = true, nowait = true, desc = "Previous codediff file" })
        end

        vim.keymap.set("n", "s", function()
          stage_codediff_entry(tabpage)
        end, { buffer = explorer.bufnr, noremap = true, silent = true, nowait = true, desc = "Stage current entry" })

        vim.keymap.set("n", "u", function()
          unstage_codediff_entry(tabpage)
        end, { buffer = explorer.bufnr, noremap = true, silent = true, nowait = true, desc = "Unstage current entry" })

        vim.keymap.set("n", "x", function()
          restore_codediff_entry(tabpage)
        end, { buffer = explorer.bufnr, noremap = true, silent = true, nowait = true, desc = "Discard current entry" })
      end
    end

    local function clear_custom_codediff_keymaps(tabpage)
      local lifecycle = get_codediff_lifecycle()
      if not lifecycle then
        return
      end

      local session = lifecycle.get_session(tabpage)
      if not session or not session.keymap_buffers then
        restore_markview_after_codediff(tabpage)
        return
      end

      restore_markview_after_codediff(tabpage)

      for bufnr, _ in pairs(session.keymap_buffers) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          for _, lhs in ipairs(custom_codediff_keymaps) do
            pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
          end
        end
      end
    end

    vim.api.nvim_create_autocmd("User", {
      group = codediff_group,
      pattern = "CodeDiffOpen",
      callback = function(args)
        local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
        set_custom_codediff_keymaps(tabpage)
      end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
      group = codediff_group,
      callback = function()
        local tabpage = vim.api.nvim_get_current_tabpage()
        vim.schedule(function()
          if vim.api.nvim_tabpage_is_valid(tabpage) then
            set_custom_codediff_keymaps(tabpage)
          end
        end)
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      group = codediff_group,
      pattern = "CodeDiffClose",
      callback = function(args)
        local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
        clear_custom_codediff_keymaps(tabpage)
      end,
    })

    require("codediff").setup {
      diff = {
        layout = "side-by-side",
        cycle_next_hunk = false,
        -- Stop at the first/last file instead of wrapping back around.
        cycle_next_file = false,
      },
      explorer = {
        width = 60,
      },
      keymaps = {
        view = {
          quit = "q",
          toggle_explorer = false,
          focus_explorer = false,
          next_hunk = "<C-j>",
          prev_hunk = "<C-k>",
          next_file = "<Tab>",
          prev_file = "<S-Tab>",
          diff_get = "do",
          diff_put = "dp",
          open_in_prev_tab = "gf",
          close_on_open_in_prev_tab = false,
          toggle_stage = false,
          stage_hunk = false,
          unstage_hunk = "<leader>hu",
          discard_hunk = false,
          hunk_textobject = "ih",
          align_move = "gm",
          toggle_layout = "t",
          show_help = "g?",
        },
        explorer = {
          select = "<CR>",
          hover = "K",
          refresh = "R",
          toggle_view_mode = "i",
          stage_all = "S",
          unstage_all = "U",
          restore = false,
          toggle_changes = "gu",
          toggle_staged = "gs",
          fold_open = "zo",
          fold_open_recursive = "zO",
          fold_close = "zc",
          fold_close_recursive = "zC",
          fold_toggle = "za",
          fold_toggle_recursive = "zA",
          fold_open_all = "zR",
          fold_close_all = "zM",
        },
      },
    }
  end,
}

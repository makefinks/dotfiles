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

local function open_diffview_for_target(target, repo, rel)
  local cmd = string.format(
    "DiffviewOpen %s -C%s -- %s",
    vim.fn.fnameescape(target),
    vim.fn.fnameescape(repo),
    vim.fn.fnameescape(rel)
  )
  vim.cmd(cmd)
end

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

local function confirm_discard_entry(callback)
  vim.ui.select({ "Cancel", "Discard" }, { prompt = "Discard current file changes?" }, function(choice)
    if choice == "Discard" then
      callback()
    end
  end)
end

return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose", "DiffviewFocusFiles" },
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    {
      "<leader>gd",
      function()
        local context = get_current_repo_file_info()
        if not context then
          return
        end
        vim.cmd("DiffviewOpen -- " .. vim.fn.fnameescape(context.abs))
      end,
      desc = "Current file diff",
    },
    {
      "<leader>gD",
      "<cmd>DiffviewOpen<cr>",
      desc = "Project diff",
    },
    {
      "<leader>gq",
      "<cmd>DiffviewClose<cr>",
      desc = "Close diffview",
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
              open_diffview_for_target(branch, context.repo, context.rel)
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
    local actions = require "diffview.actions"

    require("diffview").setup {
      enhanced_diff_hl = true, -- better syntax highlighting
      keymaps = {
        view = {
          {
            "n",
            "<leader>gs",
            actions.toggle_stage_entry,
            { desc = "Stage or unstage current file" },
          },
          {
            "n",
            "<leader>gx",
            function()
              confirm_discard_entry(actions.restore_entry)
            end,
            { desc = "Discard current file changes" },
          },
          {
            "n",
            "<leader>e",
            actions.toggle_files,
            { desc = "Toggle the file panel" },
          },
        },
        file_panel = {
          {
            "n",
            "<leader>gx",
            function()
              confirm_discard_entry(actions.restore_entry)
            end,
            { desc = "Discard current file changes" },
          },
          {
            "n",
            "<leader>e",
            actions.toggle_files,
            { desc = "Toggle the file panel" },
          },
        },
      },
    }
  end,
}

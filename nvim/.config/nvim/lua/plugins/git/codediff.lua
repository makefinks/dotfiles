local get_codediff_lifecycle
local codediff_actions = require "plugins.git.codediff.actions"
local codediff_helpers = require "plugins.git.codediff.helpers"
local codediff_keymaps = require "plugins.git.codediff.keymaps"
local codediff_view = require "plugins.git.codediff.view"

-- Safely access the active codediff lifecycle module.
get_codediff_lifecycle = function()
  local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
  if not ok then
    vim.notify("Codediff is not available", vim.log.levels.ERROR)
    return nil
  end

  return lifecycle
end

return {
  "esmuellert/codediff.nvim",
  cmd = { "CodeDiff" },
  keys = {
    {
      "<leader>gd",
      function()
        local context = codediff_helpers.get_current_repo_file_info()
        if not context then
          return
        end

        codediff_view.open_status_explorer(context.repo, context.rel, { hide_untracked = true }, get_codediff_lifecycle)
      end,
      desc = "Current file diff",
    },
    {
      "<leader>gD",
      function()
        local repo = codediff_helpers.get_cwd_repo()
        if not repo then
          return
        end

        codediff_view.open_status_explorer(repo, nil, { hide_untracked = true }, get_codediff_lifecycle)
      end,
      desc = "Project diff",
    },
    {
      "<leader>gU",
      function()
        local repo = codediff_helpers.get_cwd_repo()
        if not repo then
          return
        end

        codediff_view.open_status_explorer(repo, nil, { hide_untracked = false }, get_codediff_lifecycle)
      end,
      desc = "Project diff (with untracked)",
    },
    {
      "<leader>gq",
      function()
        codediff_view.close_view(get_codediff_lifecycle)
      end,
      desc = "Close codediff",
    },
    {
      "<leader>gF",
      function()
        local context = codediff_helpers.get_current_repo_file_info()
        if not context then
          return
        end

        vim.ui.select({ "Diff view", "Open branch file", "Open branch file (split)" }, { prompt = "View mode:" }, function(mode)
          if not mode then
            return
          end

          codediff_helpers.with_branch(function(branch)
            if mode == "Diff view" then
              vim.cmd("CodeDiff file " .. vim.fn.fnameescape(branch))
              return
            end

            local split_mode = mode == "Open branch file (split)"
            codediff_helpers.open_branch_preview(context.repo, context.rel, context.filetype, branch, split_mode)
          end)
        end)
      end,
      desc = "File in another branch",
    },
  },
  config = function()
    codediff_view.install_refresh_filter()

    local codediff_group = vim.api.nvim_create_augroup("user_codediff", { clear = true })

    vim.api.nvim_create_autocmd("User", {
      group = codediff_group,
      pattern = "CodeDiffOpen",
      callback = function(args)
        local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
        codediff_view.ensure_explorer_window_state(get_codediff_lifecycle, tabpage)
        codediff_keymaps.set_tab_keymaps(tabpage, get_codediff_lifecycle, {
          actions = codediff_actions,
          view = codediff_view,
        })
      end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
      group = codediff_group,
      callback = function()
        local tabpage = vim.api.nvim_get_current_tabpage()
        vim.schedule(function()
          if vim.api.nvim_tabpage_is_valid(tabpage) then
            codediff_view.ensure_explorer_window_state(get_codediff_lifecycle, tabpage)
            codediff_keymaps.set_tab_keymaps(tabpage, get_codediff_lifecycle, {
              actions = codediff_actions,
              view = codediff_view,
            })
          end
        end)
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      group = codediff_group,
      pattern = "CodeDiffClose",
      callback = function(args)
        local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
        codediff_keymaps.clear_tab_keymaps(tabpage, get_codediff_lifecycle, {
          actions = codediff_actions,
          view = codediff_view,
        })
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

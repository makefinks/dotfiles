local M = {}

local custom_codediff_keymaps = { "<CR>", "<Tab>", "<S-Tab>", "<C-q>", "ff", "<leader>e", "<leader>gs", "<leader>gu", "<leader>gx", "s", "u", "x" }

function M.set_tab_keymaps(tabpage, get_codediff_lifecycle, deps)
  local lifecycle = get_codediff_lifecycle()
  local session = lifecycle and lifecycle.get_session(tabpage) or nil
  if not lifecycle or not session then
    return
  end

  lifecycle.set_tab_keymap(tabpage, "n", "ff", function()
    deps.actions.open_file_picker(get_codediff_lifecycle, tabpage)
  end, { desc = "Search files in codediff" })

  lifecycle.set_tab_keymap(tabpage, "n", "<leader>e", function()
    deps.view.toggle_explorer(get_codediff_lifecycle, tabpage)
  end, { desc = "Toggle codediff explorer" })

  lifecycle.set_tab_keymap(tabpage, "n", "<leader>gs", function()
    deps.actions.toggle_stage(get_codediff_lifecycle, tabpage)
  end, { desc = "Stage/unstage current entry" })

  lifecycle.set_tab_keymap(tabpage, "n", "<leader>gu", function()
    deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
  end, { desc = "Unstage current entry" })

  lifecycle.set_tab_keymap(tabpage, "n", "<leader>gx", function()
    deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
  end, { desc = "Discard current entry" })

  lifecycle.set_tab_keymap(tabpage, "n", "<C-q>", function()
    deps.view.close_view(get_codediff_lifecycle)
  end, { desc = "Close codediff view" })

  local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
  for _, bufnr in ipairs({ original_bufnr, modified_bufnr }) do
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      session.keymap_buffers = session.keymap_buffers or {}
      session.keymap_buffers[bufnr] = true

      vim.keymap.set("n", "<leader>gs", function()
        deps.actions.stage_entry(get_codediff_lifecycle, tabpage)
      end, { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = "Stage current entry" })

      vim.keymap.set("n", "<leader>gu", function()
        deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
      end, { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = "Unstage current entry" })

      vim.keymap.set("n", "<leader>gx", function()
        deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
      end, { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = "Discard current entry" })
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
      deps.view.open_explorer_entry(get_codediff_lifecycle, tabpage, explorer)
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
      deps.actions.stage_entry(get_codediff_lifecycle, tabpage)
    end, { buffer = explorer.bufnr, noremap = true, silent = true, nowait = true, desc = "Stage current entry" })

    vim.keymap.set("n", "u", function()
      deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
    end, { buffer = explorer.bufnr, noremap = true, silent = true, nowait = true, desc = "Unstage current entry" })

    vim.keymap.set("n", "x", function()
      deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
    end, { buffer = explorer.bufnr, noremap = true, silent = true, nowait = true, desc = "Discard current entry" })
  end
end

-- Remove our custom mappings and any hidden preload buffers once the codediff tab is done.
function M.clear_tab_keymaps(tabpage, get_codediff_lifecycle, deps)
  local lifecycle = get_codediff_lifecycle()
  if not lifecycle then
    return
  end

  local session = lifecycle.get_session(tabpage)
  if not session then
    return
  end

  if session.keymap_buffers then
    for bufnr, _ in pairs(session.keymap_buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        for _, lhs in ipairs(custom_codediff_keymaps) do
          pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
        end
      end
    end
  end

end

return M

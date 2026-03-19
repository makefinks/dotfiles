local M = {}

local custom_codediff_keymaps = { "<CR>", "<Tab>", "<S-Tab>", "<C-q>", "ff", "<leader>e", "<leader>gs", "<leader>gu", "<leader>gx", "s", "u", "x" }

function M.set_tab_keymaps(tabpage, get_codediff_lifecycle, deps)
  local lifecycle = get_codediff_lifecycle()
  local session = lifecycle and lifecycle.get_session(tabpage) or nil
  if not lifecycle or not session then
    return
  end

  local function set_buffer_keymap(bufnr, lhs, rhs, desc)
    if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
      return
    end

    session.keymap_buffers = session.keymap_buffers or {}
    session.keymap_buffers[bufnr] = true

    vim.keymap.set("n", lhs, rhs, {
      buffer = bufnr,
      noremap = true,
      silent = true,
      nowait = true,
      desc = desc,
    })
  end

  lifecycle.set_tab_keymap(tabpage, "n", "ff", function()
    deps.actions.open_file_picker(get_codediff_lifecycle, tabpage)
  end, { desc = "Search files in codediff" })

  lifecycle.set_tab_keymap(tabpage, "n", "<leader>e", function()
    deps.view.toggle_explorer(get_codediff_lifecycle, tabpage)
  end, { desc = "Toggle codediff explorer" })

  lifecycle.set_tab_keymap(tabpage, "n", "<C-q>", function()
    deps.view.close_view(get_codediff_lifecycle)
  end, { desc = "Close codediff view" })

  local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
  for _, bufnr in ipairs({ original_bufnr, modified_bufnr }) do
    set_buffer_keymap(bufnr, "<leader>gs", function()
      deps.actions.stage_entry(get_codediff_lifecycle, tabpage)
    end, "Stage current entry")

    set_buffer_keymap(bufnr, "<leader>gu", function()
      deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
    end, "Unstage current entry")

    set_buffer_keymap(bufnr, "<leader>gx", function()
      deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
    end, "Discard current entry")
  end

  local explorer = lifecycle.get_explorer(tabpage)
  if explorer then
    explorer.hide_untracked = session.hide_untracked or false
  end
  if explorer and explorer.bufnr and vim.api.nvim_buf_is_valid(explorer.bufnr) then
    local ok_navigation, navigation = pcall(require, "codediff.ui.view.navigation")

    set_buffer_keymap(explorer.bufnr, "<CR>", function()
      deps.view.open_explorer_entry(get_codediff_lifecycle, tabpage, explorer)
    end, "Open current codediff entry")

    if ok_navigation then
      set_buffer_keymap(explorer.bufnr, "<Tab>", function()
        navigation.next_file()
      end, "Next codediff file")

      set_buffer_keymap(explorer.bufnr, "<S-Tab>", function()
        navigation.prev_file()
      end, "Previous codediff file")
    end

    set_buffer_keymap(explorer.bufnr, "<leader>gs", function()
      deps.actions.toggle_stage(get_codediff_lifecycle, tabpage)
    end, "Stage/unstage current entry")

    set_buffer_keymap(explorer.bufnr, "<leader>gu", function()
      deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
    end, "Unstage current entry")

    set_buffer_keymap(explorer.bufnr, "<leader>gx", function()
      deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
    end, "Discard current entry")

    set_buffer_keymap(explorer.bufnr, "s", function()
      deps.actions.stage_entry(get_codediff_lifecycle, tabpage)
    end, "Stage current entry")

    set_buffer_keymap(explorer.bufnr, "u", function()
      deps.actions.unstage_entry(get_codediff_lifecycle, tabpage)
    end, "Unstage current entry")

    set_buffer_keymap(explorer.bufnr, "x", function()
      deps.actions.restore_entry(get_codediff_lifecycle, tabpage)
    end, "Discard current entry")
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

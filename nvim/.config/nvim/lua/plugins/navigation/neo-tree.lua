return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    window = {
      width = 50,
      mapping_options = {
        noremap = true,
        nowait = true,
      },
    },
    filesystem = {
      commands = {
        find_files_in_dir = function()
          local ok_lazy, lazy = pcall(require, "lazy")
          if ok_lazy and lazy and lazy.load then
            lazy.load { plugins = { "fff.nvim" } }
          end

          local ok, fff = pcall(require, "fff")
          if ok and fff and fff.find_files then
            fff.find_files()
            return
          end

          local fallback_ok, snacks = pcall(require, "snacks")
          if fallback_ok and snacks.picker and snacks.picker.files then
            snacks.picker.files()
            return
          end
        end,
      },
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_hidden = true,
      },
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true,
      },
    },
    default_component_configs = {
      modified = {
        symbol = "[+]",
        highlight = "NeoTreeModified",
      },
      git_status = {
        symbols = {
          added = "",
          modified = "",
          deleted = "",
          renamed = "",
          untracked = "",
          ignored = "",
          unstaged = "󰄱",
          staged = "",
          conflict = "",
        },
      },
    },
  },
}

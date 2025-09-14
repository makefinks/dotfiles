return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    window = {
      width = 40,
      mapping_options = {
        noremap = true,
        nowait = true,
      },
    },
    filesystem = {
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

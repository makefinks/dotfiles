return {
  {
    "gbprod/yanky.nvim",
    dependencies = {
      "folke/snacks.nvim",
    },
    opts = {
      highlight = {
        timer = 150,
      },
      preserve_cursor_position = {
        enabled = true,
      },
      picker = {
        select = {
          action = nil,
        },
      },
    },
    keys = {
      { "y", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "Yank text" },
      { "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" }, desc = "Put after cursor" },
      { "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" }, desc = "Put before cursor" },
      { "<C-n>", "<Plug>(YankyNextEntry)", desc = "Cycle to newer yank" },
      { "<C-p>", "<Plug>(YankyPreviousEntry)", desc = "Cycle to older yank" },
      {
        "<leader>fp",
        function()
          Snacks.picker.yanky()
        end,
        desc = "Paste history",
      },
    },
  },
}

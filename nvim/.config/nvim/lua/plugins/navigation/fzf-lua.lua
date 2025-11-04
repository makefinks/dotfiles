return {
  "ibhagwan/fzf-lua",
  cmd = "FzfLua",
  opts = {
    previewers = {
      builtin = {
        snacks_image = false, -- disable snacks image preview
      },
    },
  },
  keys = {
    {
      "<leader>fj",
      "<cmd>FzfLua blines<cr>",
      desc = "Fuzzy find in buffer",
    },
  },
}

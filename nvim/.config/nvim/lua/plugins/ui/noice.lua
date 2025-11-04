return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    cmdline = { enabled = true },
    lsp = {
      progress = { enabled = false },
      signature = {
        enabled = false,
      },
      hover = {
        enabled = false,
      },
    },
  },
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
}

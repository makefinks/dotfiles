return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    cmdline = { enabled = true },
    lsp = {
      signature = {
        enabled = true,
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

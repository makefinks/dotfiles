return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("diffview").setup {
      enhanced_diff_hl = true, -- better syntax highlighting
    }
  end,
}

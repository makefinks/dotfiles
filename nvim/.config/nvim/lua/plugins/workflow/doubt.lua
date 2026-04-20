return {
  "makefinks/doubt.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  config = function()
    require("doubt").setup()
  end,
}

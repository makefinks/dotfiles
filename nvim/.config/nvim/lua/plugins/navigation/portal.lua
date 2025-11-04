return {
  "cbochs/portal.nvim",
  event = "VeryLazy",
  dependencies = {
    "cbochs/grapple.nvim",
    "ThePrimeagen/harpoon",
  },
  opts = {
    max_results = 20,
  },
  config = function(_, opts)
    require("portal").setup(opts)

    local colors = require("tokyonight.colors").setup()

    vim.api.nvim_set_hl(0, "PortalLabel", {
      bg = colors.magenta,
      fg = colors.black,
      bold = true,
    })
  end,
  keys = {
    { "<leader>o", function() require("portal.builtin").jumplist.tunnel_backward() end, desc = "Portal jumplist backward" },
    { "<leader>i", function() require("portal.builtin").jumplist.tunnel_forward() end, desc = "Portal jumplist forward" },
  },
}

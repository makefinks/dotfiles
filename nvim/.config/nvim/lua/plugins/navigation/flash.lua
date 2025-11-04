---@type Flash.Config
local flash_opts = {
  search = {
    exclude = {
      "neo-tree",
      "neo-tree-popup",
      "TelescopePrompt",
    },
  },
}

return {
  "folke/flash.nvim",
  event = "VeryLazy",
  opts = flash_opts,
  config = function(_, opts)
    require("flash").setup(opts)

    local colors = require("tokyonight.colors").setup()

    vim.api.nvim_set_hl(0, "FlashLabel", {
      bg = colors.magenta,
      fg = colors.black,
      bold = true,
    })

    vim.api.nvim_set_hl(0, "FlashLabelCurrent", {
      bg = colors.orange,
      fg = colors.black,
      bold = true,
    })

    vim.api.nvim_set_hl(0, "FlashMatch", {
      fg = colors.red,
      underline = true,
    })

    vim.api.nvim_set_hl(0, "FlashCurrent", {
      bg = colors.bg_highlight,
      fg = colors.yellow,
      bold = true,
    })

    vim.api.nvim_set_hl(0, "FlashPromptIcon", {
      fg = colors.red,
      bold = true,
    })
  end,
  -- stylua: ignore
  keys = {
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,        desc = "Flash jump" },
    { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end,  desc = "Flash TS jump" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
}

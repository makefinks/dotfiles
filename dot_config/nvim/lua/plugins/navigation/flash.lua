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
  -- stylua: ignore
  keys = {
    -- keep or change your mappings here …
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,        desc = "Flash jump" },
    { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end,  desc = "Flash TS jump" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
}

-- You can also add or configure plugins by creating files in this `plugins/` folder
-- Add your custom plugins below

---@type LazySpec
return {
  -- Add your custom plugins here
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts)
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })
    end,
  },
  {
    "better-escape.nvim",
    enabled = false,
  },
}

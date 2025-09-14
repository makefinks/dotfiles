-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua", lazy = true },
  { import = "astrocommunity.recipes.neovide", lazy = true },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    opts = {
      file_types = { "markdown", "Avante", "leetcode.nvim" }, -- Moved from avante.lua
    },
  },
  { import = "astrocommunity.colorscheme.github-nvim-theme", lazy = true },
  -- { import = "astrocommunity.completion.copilot-lua", lazy = true },
  -- import/override with your plugins folder
}

return {
  "kawre/leetcode.nvim",
  build = ":TSUpdate html",
  cmd = { "Leet" },
  enabled = require("toggles").enabled("leetcode"),
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  opts = {
    lang = "python3", -- or python3, java, etc.
    cn = { enabled = false },
    -- any other tweaks…
  },
}

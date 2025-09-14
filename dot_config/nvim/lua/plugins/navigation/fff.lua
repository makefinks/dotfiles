return {
  "dmtrKovalenko/fff.nvim",
  enabled = require("toggles").enabled "fff",
  build = "cargo build --release",
  -- or if you are using nixos
  -- build = "nix run .#release",
  opts = { -- (optional)
    debug = {
      enabled = false, -- we expect your collaboration at least during the beta
      show_scores = false, -- to help us optimize the scoring system, feel free to share your scores!
    },
    layout = {
      prompt_position = "top",
    },
    max_threads = 8,
    prompt = "⚡ ",
  },
  -- Let the plugin lazy-load on demand (keys trigger load)
  keys = {
    {
      "ff", -- try it if you didn't it is a banger keybinding for a picker
      function() require("fff").find_files() end,
      desc = "FFFind files",
    },
  },
}

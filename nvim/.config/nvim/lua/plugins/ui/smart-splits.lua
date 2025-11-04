return {
  "mrjones2014/smart-splits.nvim",
  opts = {
    -- Determines how much Cltr + Arrows key resizes
    default_amount = 20,
  },
  keys = {
    { "<C-S-Up>", function() require("smart-splits").resize_up() end, desc = "Resize split up" },
    { "<C-S-Down>", function() require("smart-splits").resize_down() end, desc = "Resize split down" },
    { "<C-S-Left>", function() require("smart-splits").resize_left() end, desc = "Resize split left" },
    { "<C-S-Right>", function() require("smart-splits").resize_right() end, desc = "Resize split right" },
  },
}

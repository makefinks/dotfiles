return {
  "zion-off/mole.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  cmd = { "MoleStart", "MoleStop", "MoleResume", "MoleToggle" },
  keys = {
    { "<leader>ms", "<cmd>MoleStart<cr>", desc = "Mole: start session" },
    { "<leader>mq", "<cmd>MoleStop<cr>", desc = "Mole: stop session" },
    { "<leader>mr", "<cmd>MoleResume<cr>", desc = "Mole: resume session" },
    { "<leader>mw", "<cmd>MoleToggle<cr>", desc = "Mole: toggle panel" },
    { "<leader>ma", mode = "v", desc = "Mole: annotate selection" },
  },
  opts = {
    -- Capture the actual code snippet instead of just its location so annotations have context.
    capture_mode = "snippet",
    picker = "snacks",
    format = {
      header = function()
        return {}
      end,
      footer = function()
        return {}
      end,
      resumed = function()
        return {}
      end,
    },
  },
}

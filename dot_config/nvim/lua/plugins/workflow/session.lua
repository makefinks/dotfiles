-- ~/.config/nvim/lua/plugins/session.lua
return {
  {
    "stevearc/resession.nvim",
    -- Load earlier so our VimEnter autocmd exists in time
    event = "VeryLazy",
    init = function()
      -- mark stdin usage like in README
      vim.api.nvim_create_autocmd("StdinReadPre", {
        callback = function() vim.g.using_stdin = true end,
      })

      vim.api.nvim_create_autocmd("VimEnter", {
        nested = true,
        callback = function()
          if vim.fn.argc(-1) == 0 and not vim.g.using_stdin then
            require("resession").load(vim.fn.getcwd(), {
              dir = "dirsession",
              silence_errors = true,
            })
          end
        end,
      })

      -- save on exit
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          require("resession").save(vim.fn.getcwd(), {
            dir = "dirsession",
            notify = false,
          })
        end,
      })
    end,

    opts = {
      -- turn off periodic autosave, we handle VimLeavePre ourselves
      autosave = { enabled = false },
      dir = "dirsession",
      extensions = {
        neo_tree = {
          enable = true,
        },
      },
    },
    config = function(_, opts)
      local resession = require "resession"
      resession.setup(opts)
    end,
  },
}

-- ~/.config/nvim/lua/user/plugins/toggleterm.lua
return {
  {
    "akinsho/toggleterm.nvim",
    cmd = { "ToggleTerm", "TermExec" },
    opts = {
      size = 15,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_terminals = true,
      start_in_insert = true,
      close_on_exit = false,
      direction = "horizontal",
    },
  },
}

-- Customize Treesitter: ensure parsers for your common languages

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      "lua",
      "vim",
      "vimdoc",
      "query",
      "python",
      "javascript",
      "typescript",
      "tsx",
      "json",
      "yaml",
      "markdown",
      "markdown_inline",
      "bash",
      "html",
      "css",
      "toml",
      "dockerfile",
    },
  },
}

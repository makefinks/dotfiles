-- Customize Treesitter: ensure parsers for your common languages

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      highlight = true,
      indent = true,
      auto_install = true,
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
  },
}

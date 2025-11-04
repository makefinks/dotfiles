return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  desc = "Auto-format on save with conform.nvim. Easily configure per-filetype formatters.",
  config = function()
    require("conform").setup {

      -- Format on save
      format_on_save = function(bufnr)
        local ignore_filetypes = { "markdown" }
        if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then return end
        return { timeout_ms = 1500, lsp_fallback = true, notify_on_error = false }
      end,

      -- Define formatters for each filetype
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        javascript = { "biome", "prettierd", "prettier" },
        javascriptreact = { "biome", "prettierd", "prettier" },
        typescript = { "biome", "prettierd", "prettier" },
        typescriptreact = { "biome", "prettierd", "prettier" },
        json = { "biome", "prettierd", "prettier" },
        yaml = { "prettierd", "prettier" },
        markdown = { "prettierd", "prettier" },
        html = { "prettierd", "prettier" },
        css = { "prettierd", "prettier" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        toml = { "taplo" },
      },
    }
  end,
}

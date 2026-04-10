local M = {}

local function prefer_core_parser(lang)
  local parser_paths = vim.api.nvim_get_runtime_file(("parser/%s.*"):format(lang), true)

  for _, path in ipairs(parser_paths) do
    if path:find("/lib/nvim/parser/", 1, true) then
      pcall(vim.treesitter.language.add, lang, { path = path })
      return
    end
  end
end

function M.prefer_core_builtin_parsers()
  for _, lang in ipairs { "c", "lua", "markdown", "markdown_inline", "query", "vim", "vimdoc" } do
    prefer_core_parser(lang)
  end
end

return M

# AstroNvim config

My AstroNvim config I use on MacOS, Omarchy and WSL.

The goal is to have a fast, functional, and aesthetically pleasing setup
that works well in times of agent assisted programming.

In particular, I maintain a [custom CodeDiff integration](lua/user/codediff/README.md)
on top of [codediff.nvim](https://github.com/esmuellert/codediff.nvim) for intuitive,
interactive diff review with LSP integration - that also works well with my doubt.nvim
review plugin.

## Dependencies

| Tool                | Purpose                                                                    |
| ------------------- | -------------------------------------------------------------------------- |
| **Neovim ≥ 0.12.0** | Editor runtime for this AstroNvim v6 config.                               |
| **Git**             | Plugin installation and Git integrations.                                  |
| **curl**            | Downloads used during setup and by tooling.                                |
| **fd**              | File discovery.                                                            |
| **ripgrep**         | File content search.                                                       |
| **fzf**             | Fuzzy selection through fzf-lua.                                           |
| **ImageMagick**     | Image conversion and previews for Snacks image support.                    |
| **Node/npm**        | Runtime and package manager for JavaScript-based language tooling.         |
| **Python**          | Runtime for Python-based tooling.                                          |
| **Rust/Cargo**      | Source-build fallback for fff.nvim; a prebuilt binary is downloaded first. |

## Plugin Overview

This list tracks the plugins configured directly in `lua/plugins/`. AstroNvim
and AstroCommunity provide additional core plugins and dependencies.

| Area               | Plugins                                                                                                                                         | Details                                                                                                        |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Navigation         | **fff.nvim**, **fzf-lua**, **flash.nvim**, **portal.nvim**, **neo-tree.nvim**, **telescope.nvim**                                               | File picking, fuzzy finding, jump navigation, project tree, and portal-style movement                          |
| Git                | **neogit**, **codediff.nvim**, **gitsigns.nvim**                                                                                                | Git UI, project/file diff review workflows, signs, hunks, and blame integration                                |
| LSP and completion | **astrolsp**, **blink.cmp**, **mason-lspconfig.nvim**, **mason-tool-installer.nvim**, **conform.nvim**, **glance.nvim**, **venv-selector.nvim** | Language servers, completion, formatting, references/definitions UI, and Python environment selection          |
| UI                 | **astroui**, **heirline.nvim**, **noice.nvim**, **cyberdream.nvim**, **tokyonight.nvim**, **smart-splits.nvim**                                 | Theme, statusline, command/message UI, and window navigation/resizing                                          |
| Editing            | **nvim-autopairs**, **yanky.nvim**, **snacks.nvim**                                                                                             | Pair insertion, yank history, pickers, notifications, dashboard, and utility UI                                |
| Markdown           | **render-markdown.nvim**, **live-preview.nvim**                                                                                                 | In-editor markdown rendering and browser preview                                                               |
| Terminal           | **toggleterm.nvim**                                                                                                                             | Managed floating, horizontal, and vertical terminals                                                           |
| Core and workflow  | **astrocore**, **vim-startuptime**, **doubt.nvim**                                                                                              | Core options and mappings, Treesitter and session settings, startup profiling, and annotation/review workflows |
| Debugging          | **nvim-dap**, **nvim-dap-view**                                                                                                                 | Debug adapter integration with a persistent debugger UI                                                        |

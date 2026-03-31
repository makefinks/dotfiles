# CodeDiff config

This folder contains the local behavior layered on top of `esmuellert/codediff.nvim`.

The goal of the setup is:

- open repo-wide or file-focused diff explorers quickly
- keep the explorer usable as a Git workflow surface
- hide untracked files by default
- preserve LSPs and markdown rendering behavior inside diff tabs

## File map

- `codediff.lua`: plugin spec, top-level keybindings, autocommands, upstream setup
- `codediff/helpers.lua`: repo resolution, branch helpers, safe module loading, untracked filtering
- `codediff/view.lua`: opening/closing diff tabs, explorer visibility, explorer refresh patch
- `codediff/actions.lua`: stage, unstage, restore, picker, explorer entry handling
- `codediff/markview.lua`: temporary markview disable/restore for markdown-like buffers
- `codediff/keymaps.lua`: tab-local mappings applied when a codediff tab opens

## Entry points

Global mappings from `codediff.lua`:

- `<leader>gd`: open codediff for the current file's repository and focus that file
- `<leader>gD`: open codediff for the current working directory's repository
- `<leader>gU`: same as project diff, but include untracked files
- `<leader>gF`: compare the current file against another branch or open that branch's version directly
- `<leader>gq`: close the current codediff tab safely

## Behavior layers

Explorer defaults:

- untracked files are hidden unless explicitly using `<leader>gU`
- the explorer refresh path is patched so the hide-untracked preference survives refreshes

Git actions:

- `gitsigns` stage mappings are removed so codediff owns `<leader>gz`
- explorer and diff buffers both support stage, unstage, and discard actions
- when codediff opens, one representative file per LSP/root pair is loaded in the background
- those temporary buffers are deleted when the codediff tab closes

Markview handling:

- markdown-like buffers inside codediff have markview disabled temporarily
- the previous enabled state is restored on close

## Local codediff keymaps

Inside codediff tabs:

- `<leader>e`: toggle explorer
- `ff`: picker for all files currently in the explorer
- `<leader>gz`: toggle stage / unstage current entry
- `<leader>gx`: discard current entry
- `<C-q>`: close codediff
- `s`: stage current entry
- `u`: unstage current entry
- `x`: discard current entry

Explorer-specific:

- `<CR>`: open file or expand/collapse tree node
- `<Tab>` / `<S-Tab>`: next / previous file

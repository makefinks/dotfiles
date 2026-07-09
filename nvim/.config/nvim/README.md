# AstroNvim config

This Neovim config is used by me and designed to work across WSL (Ubuntu), macOS, and probably most Linux distros.
The purpose is to have single configuration that can be used at home and work with a toggle for certain plugins/features.
Built for Neovim >= 0.12.0.

The goal is to have a fast, functional, and aesthetically pleasing setup.

## Highlights

All of AstroNvim's features for easy configuration and:

- [fff.nvim](https://github.com/dmtrKovalenko/fff.nvim) > Super fast + Typo resistant + project aware file picker
- [flash.nvim](https://github.com/folke/flash.nvim) > Intuitive and fast navigation with treesitter integration
- [neogit.nvim](https://github.com/NeogitOrg/neogit) > Nice graphical interface for git with good diff integration
- [snacks.nvim](https://github.com/folke/snacks.nvim) > Collection of QoL and UI features + pickers

# Extra Installs (Cross-Platform)

## Dependencies for Neovim, plugins, and dev tools.

### Ubuntu / Debian

```bash
# Prerequisites
sudo apt update
sudo apt install -y neovim
sudo apt install -y nodejs
sudo apt install -y python3 python3-pip python3-pynvim
sudo apt install -y rustc cargo

# Additional tools
sudo apt install -y fd-find
if ! command -v fd &>/dev/null; then
  sudo ln -s $(which fdfind) /usr/local/bin/fd
fi

sudo apt install -y fzf
sudo apt install -y imagemagick
sudo apt install -y luarocks
sudo apt install -y wget
sudo apt install -y ripgrep

# Python/Node clients
if ! command -v npm &>/dev/null; then
  sudo apt install -y npm
fi
sudo npm install -g neovim
```

---

### macOS (Homebrew)

```bash
# Prerequisites
brew install neovim
brew install node
brew install python
brew install rust

# Additional tools
brew install fd
brew install fzf
brew install imagemagick
brew install luarocks
brew install wget
brew install ripgrep

# Python/Node clients
npm install -g neovim
pip install pynvim
```

---

## Dependency Overview

| Tool               | Purpose                                                                                  |
| ------------------ | ---------------------------------------------------------------------------------------- |
| **fd**             | Fast alternative to `find`. File searches complete in milliseconds rather than minutes.  |
| **fzf**            | Fuzzy finder. Enables fuzzy search and selection in command line and plugins.             |
| **ImageMagick**    | Command-line image processing. Handles previews, conversions, and basic manipulations.   |
| **Luarocks**       | Lua package manager. Installs Lua libraries required by various plugins.                 |
| **wget**           | Downloads files from HTTP/HTTPS/FTP. Scripts rely on it for fetching external resources. |
| **ripgrep**        | Ultra-fast text search. Powers plugin search functionality and file content queries.     |
| **rust/cargo**     | Rust toolchain. Required for compiling native plugins like fff.nvim file picker.         |
| **neovim**         | Modern Vim fork with async plugins and improved scripting support.                       |
| **node/npm**       | JavaScript runtime and package manager. Required for JavaScript-based plugins.           |
| **python/pip**     | Python runtime and package manager. Required for Python-based plugins and LSP servers.   |
| **neovim clients** | Language bridges. Enable Python/JS plugins to communicate with Neovim.                   |

## Plugin Overview

This list tracks the top-level plugins configured in `lua/plugins/`. AstroNvim and AstroCommunity provide additional core plugins and dependencies.

| Area | Plugins | Details |
| ---- | ------- | ------- |
| Navigation | **fff.nvim**, **fzf-lua**, **flash.nvim**, **portal.nvim**, **neo-tree.nvim**, **telescope.nvim** | File picking, fuzzy finding, jump navigation, project tree, and portal-style movement |
| Git | **neogit**, **codediff.nvim**, **gitsigns.nvim** | Git UI, project/file diff review workflows, signs, hunks, and blame integration |
| LSP and completion | **AstroLSP**, **blink.cmp**, **mason.nvim**, **mason-tool-installer**, **conform.nvim**, **nvim-treesitter**, **glance.nvim**, **venv-selector.nvim** | Language servers, completion, formatting, syntax parsing, references/definitions UI, and Python env selection |
| UI | **astroui**, **heirline.nvim**, **noice.nvim**, **cyberdream.nvim**, **tokyonight.nvim**, **smart-splits.nvim** | Theme, statusline, command/message UI, and window navigation/resizing |
| Editing | **nvim-autopairs**, **yanky.nvim**, **snacks.nvim** | Pair insertion, yank history, pickers, notifications, dashboard, and utility UI |
| Markdown | **render-markdown.nvim**, **live-preview.nvim** | In-editor markdown rendering and browser preview |
| Terminal | **toggleterm.nvim** | Managed floating, horizontal, and vertical terminals |
| Workflow | **resession.nvim**, **vim-startuptime**, **mole.nvim**, **doubt.nvim** | Session saving, startup profiling, annotation/review sessions, and local workflow tooling |
| Debugging | **nvim-dap**, **nvim-dap-view** | Debug adapter integration with a persistent debugger UI |

## Validate

From this Neovim config directory, the main commands are:

```bash
stylua .
selene .
./tests/run.sh
```

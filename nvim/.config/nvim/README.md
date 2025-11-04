# AstroNvim config

This neovim config is used by me and designed to work across WSL (Ubuntu) / and MacOS (and probably on most linux distros).
The purpose is to have single configuration that can be used at home and work with a toggle for certain plugins/features.

The goal is to have fast and functional but also asthetically pleasing setup.

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
sudo apt install -y npm
sudo apt install -y python3 python3-pip
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
npm install -g neovim
pip install pynvim
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

| Plugin               | Purpose                  | Home | Work | Details                                                                                            |
| -------------------- | ------------------------ | ---- | ---- | -------------------------------------------------------------------------------------------------- |
| **fff**              | File picker              | ✓    | ✓    | Super fast + Typo resistant + project aware file picker                                            |
| **neogit**           | Git integration          | ✓    | ✓    | Magit-style Git interface within Neovim for staging, committing, branching, and viewing diffs      |
| **flash**            | Enhanced search & motion | ✓    | ✓    | Super-fast navigation with labels for jumping to any location in visible text                      |
| **conform**          | Code formatting          | ✓    | ✓    | Auto-formats code on save with configurable formatters per filetype (StyLua, Prettier, Ruff, etc.) |
| **noice**            | Enhanced command line    | ✓    | ✓    | Replaces default cmdline with better UI, notifications, and command history                        |
| **snacks**           | Utility collection       | ✓    | ✓    | Provides dashboard, notifications, file picker and other UI utils                                  |
| **toggleterm**       | Terminal management      | ✓    | ✓    | Quick terminal access with customizable layouts (horizontal/vertical/float)                        |
| **autopairs**        | Auto-closing brackets    | ✓    | ✓    | Automatically closes brackets, quotes, and pairs with smart rules for different filetypes          |
| **resession**        | Session management       | ✓    | ✓    | Auto-saves and restores workspace sessions including open files, cursor positions, and layout      |
| **markdown-preview** | Live markdown preview    | ✓    | ✓    | Real-time preview of markdown files with GitHub-style rendering                                    |
| **startup-time**     | Performance monitoring   | ✓    | ✓    | Tracks and displays Neovim startup time for optimization                                           |
| **none-ls**          | Formatting & linting     | ✓    | ✓    | Provides formatting and linting capabilities as an alternative to LSP                              |
| **leetcode**         | LeetCode integration     | ✓    | ✗    | LeetCode directly inside of neovim                                                                 |
| **typr**             | Typing practice          | ✓    | ✗    | Monkey-type inspired typing practice tool                                                          |

# dotfiles

Personal configuration files for neovim, tmux, and ghostty.

## Install

```bash
./setup.sh
```

The script will:
- Auto-detect OS and install dependencies (stow, neovim, tmux, ghostty)
- Create symlinks for all configs
- Back up existing files to `~/.dotfiles_backup_<timestamp>`

## What's included

- **nvim** - Neovim config with AstroNvim
- **tmux** - Terminal multiplexer config
- **ghostty** - Terminal emulator config

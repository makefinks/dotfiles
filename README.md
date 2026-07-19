# dotfiles

Personal configuration files for Zsh, Neovim, tmux, and Ghostty.

## Install

```bash
./setup.sh
```

The script will:

- Auto-detect OS and install dependencies (stow, zsh, neovim, tmux, and supporting tools)
- Use Omarchy's package helper when it is available on Arch Linux
- Clone or update Oh My Zsh and the Powerlevel10k theme
- Create symlinks for `zsh`, `nvim`, `tmux`, and `ghostty` with GNU Stow
- Back up only existing Ghostty, Neovim, tmux, and Zsh configs to `~/.dotfiles_backup_<timestamp>`
- Add a source line to `~/.zshrc` for the managed Oh My Zsh config

## What's included

- **nvim** - Neovim config with AstroNvim
- **tmux** - Terminal multiplexer config
- **ghostty** - Terminal emulator config
- **zsh** - Oh My Zsh config with the Powerlevel10k prompt

Only `zsh`, `nvim`, `tmux`, and `ghostty` are stowed by `setup.sh`.

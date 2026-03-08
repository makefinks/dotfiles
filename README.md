# dotfiles

Personal configuration files for Zsh, Neovim, tmux, and Ghostty.

## Install

```bash
./setup.sh
```

The script will:
- Auto-detect OS and install dependencies (stow, zsh, neovim, tmux, and supporting tools)
- Clone or update Oh My Zsh and the Powerlevel10k theme
- Create symlinks for all configs
- Back up existing files to `~/.dotfiles_backup_<timestamp>`

After setup, you can make Zsh your default shell manually with:

```bash
chsh -s "$(command -v zsh)"
```

## What's included

- **nvim** - Neovim config with AstroNvim
- **tmux** - Terminal multiplexer config
- **ghostty** - Terminal emulator config
- **zsh** - Oh My Zsh config with the Powerlevel10k prompt

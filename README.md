# dotfiles

Personal configuration files for Zsh, Neovim, tmux, Ghostty, and Pi.

## Install

```bash
./setup.sh
```

The script will:

- Auto-detect OS and install dependencies (stow, zsh, neovim, tmux, and supporting tools)
- Use Omarchy's package helper when it is available on Arch Linux
- Clone or update Oh My Zsh and the Powerlevel10k theme
- Create symlinks for `zsh`, `nvim`, `tmux`, `ghostty`, and `pi` with GNU Stow
- Install configured Pi packages when the `pi` CLI is already available
- Back up only existing Ghostty, Neovim, tmux, Zsh, and Pi configs to `~/.dotfiles_backup_<timestamp>`
- Add a source line to `~/.zshrc` for the managed Oh My Zsh config

## What's included

- **nvim** - Neovim config with AstroNvim
- **tmux** - Terminal multiplexer config
- **ghostty** - Terminal emulator config
- **zsh** - Oh My Zsh config with the Powerlevel10k prompt
- **pi (experimental)** - An early experiment with Pi settings, keybindings, extensions, and themes

I'm still experimenting with Pi, so this setup is not settled. Pi credentials, trust decisions, sessions, and installed package files stay outside the repository. There are currently no global prompts or skills to track.

Only `zsh`, `nvim`, `tmux`, `ghostty`, and `pi` are stowed by `setup.sh`. Pi itself is not installed by the bootstrap script.

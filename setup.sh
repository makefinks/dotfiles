#!/usr/bin/env bash
set -euo pipefail

PKGS=("nvim" "tmux" "ghostty" "zsh")
TARGET="$HOME"
BACKUP="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
OH_MY_ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$OH_MY_ZSH_DIR/custom}"
POWERLEVEL10K_DIR="$OH_MY_ZSH_CUSTOM_DIR/themes/powerlevel10k"
ZSH_RC="$HOME/.zshrc"
DOTFILES_ZSH_RC="$HOME/.zshrc.oh-my-zsh"

clone_or_update_repo() {
  local name="$1"
  local repo_url="$2"
  local dest="$3"

  if [[ -d "$dest/.git" ]]; then
    echo "Updating $name..."
    git -C "$dest" pull --ff-only
    return
  fi

  if [[ -e "$dest" ]]; then
    echo "$name path already exists and is not a git repository: $dest"
    exit 1
  fi

  echo "Cloning $name..."
  mkdir -p "$(dirname "$dest")"
  git clone --depth 1 "$repo_url" "$dest"
}

ensure_zshrc_sources_dotfiles() {
  local source_line="[[ -r \"$DOTFILES_ZSH_RC\" ]] && source \"$DOTFILES_ZSH_RC\""
  local old_dotfiles_zshrc="$DOTFILES_DIR/zsh/.zshrc"

  if [[ -L "$ZSH_RC" ]]; then
    local link_target
    link_target="$(readlink "$ZSH_RC")"
    if [[ "$link_target" == "$old_dotfiles_zshrc" || "$HOME/$link_target" == "$old_dotfiles_zshrc" ]]; then
      rm "$ZSH_RC"
    fi
  fi

  touch "$ZSH_RC"

  if ! grep -Fqx "$source_line" "$ZSH_RC"; then
    printf '\n%s\n' "$source_line" >> "$ZSH_RC"
  fi
}

# Install dependencies
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  echo "Installing dependencies via Homebrew..."
  brew install stow neovim tmux zsh git curl node python rust fd ripgrep fzf wget imagemagick luarocks viu

  echo "Installing neovim language clients..."
  npm install -g neovim
  pip3 install pynvim
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if command -v apt-get &>/dev/null; then
    echo "Installing dependencies via apt..."
    sudo apt-get update
    sudo apt-get install -y stow neovim tmux zsh git curl npm python3 python3-pip rustc cargo fd-find ripgrep fzf wget imagemagick luarocks

    if ! command -v fd &>/dev/null; then
      sudo ln -s "$(which fdfind)" /usr/local/bin/fd
    fi

    echo "Installing neovim language clients..."
    npm install -g neovim
    pip3 install pynvim
  elif command -v dnf &>/dev/null; then
    echo "Installing dependencies via dnf..."
    sudo dnf install -y stow neovim tmux zsh git curl nodejs python3 python3-pip rust cargo fd-find ripgrep fzf wget ImageMagick luarocks

    echo "Installing neovim language clients..."
    npm install -g neovim
    pip3 install pynvim
  elif command -v pacman &>/dev/null; then
    echo "Installing dependencies via pacman..."
    sudo pacman -S --noconfirm stow neovim tmux zsh git curl nodejs python python-pip rust fd ripgrep fzf wget imagemagick luarocks

    echo "Installing neovim language clients..."
    npm install -g neovim
    pip install pynvim viu
  else
    echo "Unsupported package manager. Please install dependencies manually"
    exit 1
  fi
else
  echo "Unsupported OS. Please install dependencies manually"
  exit 1
fi

echo "Installing Oh My Zsh and Powerlevel10k..."
clone_or_update_repo "Oh My Zsh" "https://github.com/ohmyzsh/ohmyzsh.git" "$OH_MY_ZSH_DIR"
clone_or_update_repo "Powerlevel10k" "https://github.com/romkatv/powerlevel10k.git" "$POWERLEVEL10K_DIR"

# Backup any real files that would collide with our links
mkdir -p "$BACKUP"
for pkg in "${PKGS[@]}"; do
  (cd "$pkg" && find . -mindepth 1 | while read -r p; do
    dest="$TARGET/${p#./}"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      mkdir -p "$BACKUP/$(dirname "$dest")"
      mv -v "$dest" "$BACKUP/$dest"
    fi
  done)
done

# Create (or refresh) symlinks
stow -v -R -t "$TARGET" "${PKGS[@]}"

ensure_zshrc_sources_dotfiles

echo "Done. Backups (if any): $BACKUP"

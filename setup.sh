set -euo pipefail

PKGS=("nvim" "tmux" "ghostty")
TARGET="$HOME"
BACKUP="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Install dependencies
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  echo "Installing dependencies via Homebrew..."
  brew install stow neovim tmux node python rust fd ripgrep fzf wget imagemagick luarocks

  echo "Installing neovim language clients..."
  npm install -g neovim
  pip3 install pynvim
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if command -v apt-get &>/dev/null; then
    echo "Installing dependencies via apt..."
    sudo apt-get update
    sudo apt-get install -y stow neovim tmux npm python3 python3-pip rustc cargo fd-find ripgrep fzf wget imagemagick luarocks

    if ! command -v fd &>/dev/null; then
      sudo ln -s $(which fdfind) /usr/local/bin/fd
    fi

    echo "Installing neovim language clients..."
    npm install -g neovim
    pip3 install pynvim
  elif command -v dnf &>/dev/null; then
    echo "Installing dependencies via dnf..."
    sudo dnf install -y stow neovim tmux nodejs python3 python3-pip rust cargo fd-find ripgrep fzf wget ImageMagick luarocks

    echo "Installing neovim language clients..."
    npm install -g neovim
    pip3 install pynvim
  elif command -v pacman &>/dev/null; then
    echo "Installing dependencies via pacman..."
    sudo pacman -S --noconfirm stow neovim tmux nodejs python python-pip rust fd ripgrep fzf wget imagemagick luarocks

    echo "Installing neovim language clients..."
    npm install -g neovim
    pip install pynvim
  else
    echo "Unsupported package manager. Please install dependencies manually"
    exit 1
  fi
else
  echo "Unsupported OS. Please install dependencies manually"
  exit 1
fi

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

echo "Done. Backups (if any): $BACKUP"

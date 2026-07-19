#!/usr/bin/env bash
set -euo pipefail

PKGS=("nvim" "tmux" "ghostty" "zsh")
MANAGED_PATHS=(
	".config/ghostty"
	".config/nvim"
	".config/zsh"
	".tmux.conf"
	".zshrc.oh-my-zsh"
)
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
		printf '\n%s\n' "$source_line" >>"$ZSH_RC"
	fi
}

# Install dependencies
if [[ "$OSTYPE" == "darwin"* ]]; then
	if ! command -v brew &>/dev/null; then
		echo "Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi

	echo "Installing dependencies via Homebrew..."
	brew install stow neovim tmux zsh git curl node python rust fd ripgrep fzf wget imagemagick luarocks viu shfmt shellcheck

	echo "Installing neovim language clients..."
	npm install -g neovim
	pip3 install pynvim
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
	if command -v apt-get &>/dev/null; then
		echo "Installing dependencies via apt..."
		sudo apt-get update
		sudo apt-get install -y stow neovim tmux zsh git curl nodejs python3 python3-pip python3-pynvim rustc cargo fd-find ripgrep fzf wget imagemagick luarocks shfmt shellcheck

		if ! command -v npm &>/dev/null; then
			sudo apt-get install -y npm
		fi

		if ! command -v fd &>/dev/null; then
			sudo ln -s "$(which fdfind)" /usr/local/bin/fd
		fi

		echo "Installing neovim language clients..."
		sudo npm install -g neovim
	elif command -v dnf &>/dev/null; then
		echo "Installing dependencies via dnf..."
		sudo dnf install -y stow neovim tmux zsh git curl nodejs python3 python3-pip rust cargo fd-find ripgrep fzf wget ImageMagick luarocks shfmt ShellCheck

		echo "Installing neovim language clients..."
		sudo npm install -g neovim
		pip3 install pynvim
	elif command -v pacman &>/dev/null; then
		echo "Installing dependencies via pacman..."
		arch_packages=(stow neovim tmux ghostty zsh git curl nodejs npm python python-pynvim rust fd ripgrep fzf wget imagemagick luarocks viu shfmt shellcheck)
		if command -v omarchy &>/dev/null; then
			omarchy pkg add "${arch_packages[@]}"
		else
			sudo pacman -S --needed --noconfirm "${arch_packages[@]}"
		fi

		echo "Installing neovim language clients..."
		sudo npm install -g neovim
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

# Back up only the application configs owned by this repository. Walking each
# Stow package also visits .config itself, which would move the entire directory.
mkdir -p "$BACKUP"
for rel_path in "${MANAGED_PATHS[@]}"; do
	dest="$TARGET/$rel_path"
	if [[ -e "$dest" && ! -L "$dest" ]]; then
		mkdir -p "$BACKUP/$(dirname "$rel_path")"
		mv -v "$dest" "$BACKUP/$rel_path"
	fi
done

# Create (or refresh) symlinks
stow -v -R --dir="$DOTFILES_DIR" --target="$TARGET" "${PKGS[@]}"

ensure_zshrc_sources_dotfiles

echo "Done. Backups (if any): $BACKUP"

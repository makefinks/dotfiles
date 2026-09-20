#!/usr/bin/env bash
set -euo pipefail

PKGS=("nvim" "tmux" "ghostty" "zsh" "pi")
MANAGED_PATHS=(
	".config/ghostty"
	".config/nvim"
	".config/zsh"
	".pi/settings.json"
	".pi/agent/settings.json"
	".pi/agent/mcp.json"
	".pi/agent/themes/dark-blue-code.json"
	".pi/agent/keybindings.json"
	".pi/agent/extensions/leader-hotkeys.ts"
	".pi/agent/extensions/hide-input-bottom-border.ts"
	".pi/agent/extensions/keep-last-model.ts"
	".pi/agent/extensions/single-line-footer.ts"
	".pi/agent/extensions/quotas.json"
	".pi/agent/extensions/pi-tool-display/config.json"
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

# Section banners (plain text when not a terminal).
if [[ -t 1 ]] && command -v tput &>/dev/null; then
	C_BOLD="$(tput bold)"
	C_STEP="$(tput setaf 5)"
	C_RESET="$(tput sgr0)"
else
	C_BOLD=""
	C_STEP=""
	C_RESET=""
fi

step() {
	local title="STEP $1 - $2"
	printf '\n%s╔══════════════════════════════════════════════════╗\n' "$C_BOLD$C_STEP"
	printf '║  %-46.46s  ║\n' "$title"
	printf '╚══════════════════════════════════════════════════╝%s\n' "$C_RESET"
}

# Quiet by default; pass --verbose to see full tool output.
VERBOSE=0
if [[ "${1:-}" == "--verbose" ]]; then
	VERBOSE=1
elif [[ -n "${1:-}" ]]; then
	echo "Usage: $0 [--verbose]" >&2
	exit 1
fi

# Quiet flags are plain strings (not arrays) for macOS bash 3.2 compat.
if [[ $VERBOSE == 1 ]]; then
	GIT_Q=""
	NPM_Q=""
	STOW_Q="-v"
	MV_Q="-v"
else
	GIT_Q="--quiet"
	NPM_Q="--silent --no-audit --no-fund"
	STOW_Q=""
	MV_Q=""
fi

# Run a noisy command, hiding stdout unless --verbose (stderr still shows).
run() {
	if [[ $VERBOSE == 1 ]]; then
		"$@"
	else
		"$@" >/dev/null
	fi
}

clone_or_update_repo() {
	local name="$1"
	local repo_url="$2"
	local dest="$3"

	if [[ -d "$dest/.git" ]]; then
		echo "Updating $name..."
		git -C "$dest" pull ${GIT_Q} --ff-only
		return
	fi

	if [[ -e "$dest" ]]; then
		echo "$name path already exists and is not a git repository: $dest"
		exit 1
	fi

	echo "Cloning $name..."
	mkdir -p "$(dirname "$dest")"
	git clone ${GIT_Q} --depth 1 "$repo_url" "$dest"
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

install_pi_packages() {
	if ! command -v pi >/dev/null 2>&1; then
		echo "Pi is not installed; skipping configured Pi packages."
		return
	fi

	local settings_file="$DOTFILES_DIR/pi/.pi/agent/settings.json"
	while IFS= read -r package; do
		[[ -n "$package" ]] || continue
		[[ $VERBOSE == 1 ]] && echo "Installing Pi package $package..."
		run pi install "$package"
	done < <(node -e '
const fs = require("fs");
const settings = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
for (const package of settings.packages ?? []) {
	const source = typeof package === "string" ? package : package?.source;
	if (typeof source === "string") console.log(source);
}
' "$settings_file")
}

# Install dependencies
step "1/5" "System dependencies"
if [[ "$OSTYPE" == "darwin"* ]]; then
	if ! command -v brew &>/dev/null; then
		echo "Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi

	echo "Installing dependencies via Homebrew..."
	run brew install stow neovim tmux zsh git curl node python rust fd ripgrep fzf imagemagick shfmt shellcheck

	echo "Installing neovim node client..."
	# shellcheck disable=SC2086
	run npm install -g ${NPM_Q} neovim
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
	if command -v apt-get &>/dev/null; then
		echo "Installing dependencies via apt..."
		run sudo apt-get update
		run sudo apt-get install -y stow neovim tmux zsh git curl nodejs python3 rustc cargo fd-find ripgrep fzf imagemagick shfmt shellcheck

		if ! command -v npm &>/dev/null; then
			run sudo apt-get install -y npm
		fi

		if ! command -v fd &>/dev/null; then
			sudo ln -s "$(which fdfind)" /usr/local/bin/fd
		fi

		echo "Installing neovim node client..."
		# shellcheck disable=SC2086
		run sudo npm install -g ${NPM_Q} neovim
	elif command -v dnf &>/dev/null; then
		echo "Installing dependencies via dnf..."
		run sudo dnf install -y stow neovim tmux zsh git curl nodejs python3 rust cargo fd-find ripgrep fzf ImageMagick shfmt ShellCheck

		echo "Installing neovim node client..."
		# shellcheck disable=SC2086
		run sudo npm install -g ${NPM_Q} neovim
	elif command -v pacman &>/dev/null; then
		echo "Installing dependencies via pacman..."
		arch_packages=(stow neovim tmux ghostty zsh git curl nodejs npm python rust fd ripgrep fzf imagemagick shfmt shellcheck)
		if command -v omarchy &>/dev/null; then
			run omarchy pkg add "${arch_packages[@]}"
		else
			run sudo pacman -S --needed --noconfirm "${arch_packages[@]}"
		fi

		echo "Installing neovim node client..."
		# shellcheck disable=SC2086
		run sudo npm install -g ${NPM_Q} neovim
	else
		echo "Unsupported package manager. Please install dependencies manually"
		exit 1
	fi
else
	echo "Unsupported OS. Please install dependencies manually"
	exit 1
fi

step "2/5" "Oh My Zsh and Powerlevel10k"
clone_or_update_repo "Oh My Zsh" "https://github.com/ohmyzsh/ohmyzsh.git" "$OH_MY_ZSH_DIR"
clone_or_update_repo "Powerlevel10k" "https://github.com/romkatv/powerlevel10k.git" "$POWERLEVEL10K_DIR"

step "3/5" "Backing up and linking dotfiles"
# Keep Pi's generated auth, sessions, and package files outside the Stow package.
mkdir -p "$TARGET/.pi/agent/extensions" "$TARGET/.pi/agent/themes"

# Back up only the application configs owned by this repository. Walking each
# Stow package also visits .config itself, which would move the entire directory.
mkdir -p "$BACKUP"
BACKED_UP=0
for rel_path in "${MANAGED_PATHS[@]}"; do
	dest="$TARGET/$rel_path"
	if [[ -e "$dest" && ! -L "$dest" ]]; then
		mkdir -p "$BACKUP/$(dirname "$rel_path")"
		mv ${MV_Q} "$dest" "$BACKUP/$rel_path"
		BACKED_UP=$((BACKED_UP + 1))
	fi
done
echo "Backed up $BACKED_UP file(s) to $BACKUP."

# Create (or refresh) symlinks
stow ${STOW_Q} -R --dir="$DOTFILES_DIR" --target="$TARGET" "${PKGS[@]}"

step "4/5" "Pi extensions"
install_pi_packages
step "5/5" "Shell integration"
ensure_zshrc_sources_dotfiles

printf '%sDone.%s Linked %d packages, backed up %d file(s): %s\n' "$C_BOLD" "$C_RESET" "${#PKGS[@]}" "$BACKED_UP" "$BACKUP"

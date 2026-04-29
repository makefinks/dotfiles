#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NVIM_DIR="$ROOT_DIR/nvim/.config/nvim"

require_cmd() {
	local cmd="$1"

	if ! command -v "$cmd" >/dev/null 2>&1; then
		printf 'Missing required command: %s\n' "$cmd" >&2
		exit 127
	fi
}

require_cmd shfmt
require_cmd shellcheck
require_cmd stylua
require_cmd selene
require_cmd nvim

shfmt -w "$ROOT_DIR/setup.sh" "$ROOT_DIR/scripts/check.sh"
shellcheck "$ROOT_DIR/setup.sh" "$ROOT_DIR/scripts/check.sh"

stylua "$NVIM_DIR"
(
	cd "$NVIM_DIR"
	selene .
	./tests/run.sh
)

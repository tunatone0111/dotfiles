#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Claude Code settings ---
echo "Installing .claude/ -> $HOME/.claude/"
mkdir -p "$HOME/.claude"
cp -r "$DOTFILES_DIR/.claude/." "$HOME/.claude/"

# --- Add more sections below as needed ---

echo "Done."

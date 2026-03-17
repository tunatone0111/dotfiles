#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Init submodules (for fresh clones) ---
git -C "$DOTFILES_DIR" submodule update --init --recursive

# --- Claude Code settings ---
echo "Installing .claude/settings.json"
mkdir -p "$HOME/.claude"
cp "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"

# --- Claude Scientific Skills ---
SKILLS_SRC="$DOTFILES_DIR/.claude/scientific-skills-repo/scientific-skills"
SKILLS_DST="$HOME/.claude/skills"

if [ -d "$SKILLS_SRC" ]; then
  echo "Installing scientific skills -> $SKILLS_DST/"
  mkdir -p "$SKILLS_DST"
  cp -r "$SKILLS_SRC"/. "$SKILLS_DST/"
else
  echo "Warning: scientific-skills-repo not found. Run: git submodule update --init --recursive"
fi

# --- ccstatusline settings ---
echo "Installing ccstatusline settings"
mkdir -p "$HOME/.config/ccstatusline"
cp "$DOTFILES_DIR/.config/ccstatusline/settings.json" "$HOME/.config/ccstatusline/settings.json"

# --- Add more sections below as needed ---

echo "Done."

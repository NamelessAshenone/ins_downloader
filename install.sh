#!/usr/bin/env bash
set -euo pipefail

# Minimal macOS bootstrap for ins_download helpers
# Requirements: Homebrew installed

command -v brew >/dev/null 2>&1 || { echo "brew not found. Install Homebrew first: https://brew.sh"; exit 1; }

echo "==> Installing Python (if needed)"
brew list python >/dev/null 2>&1 || brew install python

echo "==> Installing gallery-dl (user scope)"
python3 -m pip install --user --upgrade gallery-dl

echo "==> (Optional) Installing ffmpeg"
brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg

echo "==> Done. Restart your shell; functions are already in ~/.zshrc"

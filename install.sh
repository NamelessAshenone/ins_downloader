#!/usr/bin/env bash
set -euo pipefail

# macOS / Linux bootstrap for ins_download helpers
# Requirements: Homebrew installed (macOS)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v brew >/dev/null 2>&1 || { echo "brew not found. Install Homebrew first: https://brew.sh"; exit 1; }

echo "==> Installing Python (if needed)"
brew list python >/dev/null 2>&1 || brew install python

echo "==> Installing gallery-dl (user scope)"
python3 -m pip install --user --upgrade gallery-dl

# Ensure Python user bin directory is in PATH
_py_user_base=$(python3 -c "import sysconfig, os; print(sysconfig.get_path('scripts', f'posix_user'))" 2>/dev/null || true)
if [[ -n "$_py_user_base" && -d "$_py_user_base" ]]; then
    case ":$PATH:" in
        *":$_py_user_base:"*) ;;
        *) export PATH="$_py_user_base:$PATH"
           echo "Added $_py_user_base to session PATH." ;;
    esac
fi

echo "==> (Optional) Installing ffmpeg"
if ! brew list ffmpeg >/dev/null 2>&1; then
    printf "Install ffmpeg via Homebrew? [Y/n] "
    read -r resp
    if [[ -z "$resp" || "$resp" =~ ^[Yy]$ ]]; then
        brew install ffmpeg
    else
        echo "Skipped ffmpeg."
    fi
fi

echo "==> Copying ins_tools.sh"
TARGET_DIR="${HOME}/.local/bin"
printf "Where to place ins_tools.sh? (Default: %s; enter 'skip' to skip): " "$TARGET_DIR"
read -r user_target
if [[ -n "$user_target" && "$user_target" != "skip" ]]; then
    TARGET_DIR="$user_target"
fi
if [[ "${user_target:-}" == "skip" ]]; then
    echo "Skipped copy."
    TOOLS_PATH=""
else
    mkdir -p "$TARGET_DIR"
    cp "$SCRIPT_DIR/ins_tools.sh" "$TARGET_DIR/ins_tools.sh"
    TOOLS_PATH="$TARGET_DIR/ins_tools.sh"
    echo "Copied to $TOOLS_PATH"
fi

echo "==> Updating shell config"
if [[ -n "${TOOLS_PATH:-}" ]]; then
    # Detect shell config file
    if [[ "$(basename "${SHELL:-/bin/bash}")" == "zsh" ]]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi

    # Ensure Python user bin directory is in shell PATH
    if [[ -n "${_py_user_base:-}" && -d "$_py_user_base" ]]; then
        PATH_LINE="export PATH=\"$_py_user_base:\$PATH\""
        if ! grep -qF "$_py_user_base" "$SHELL_RC" 2>/dev/null; then        
            echo "Added Python user bin directory to $SHELL_RC"
        fi
    fi

    SOURCE_LINE="source \"$TOOLS_PATH\""
    if grep -qF "$SOURCE_LINE" "$SHELL_RC" 2>/dev/null; then
        echo "Shell config ($SHELL_RC) already contains source line."
    else
        printf "Add source line to %s? [Y/n] " "$SHELL_RC"
        read -r resp
        if [[ -z "$resp" || "$resp" =~ ^[Yy]$ ]]; then
            echo "$SOURCE_LINE" >> "$SHELL_RC"
            echo "Added to $SHELL_RC"
        else
            echo "Skipped. Add manually: $SOURCE_LINE"
        fi
    fi
fi

echo "==> Done. Restart your shell, then verify with: ins_download -h"

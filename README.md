# Instagram Download Helpers (macOS + Windows)

This project provides small helper functions to download Instagram media with alias support and post/media limits. It mirrors the macOS zsh helpers (`ins_alias`, `ins_download`) and adds a Windows PowerShell variant.

## Features
- Alias mapping: map short aliases to real usernames via a simple `~/.ins_aliases` file (shared across macOS and Windows).
- Download by URL, username, or alias.
- Limits:
  - URL mode: unlimited by default; when `-l/--limit` is provided, caps per-post media (default 5 if value omitted).
  - Username/Alias mode: total download cap (default 20; override with `-l/--limit`).
  - `-t/--top` to restrict posts (first N posts for user/alias; first N media for a single URL post).
- Anti-scrape: random 1–5s request sleep; backoff notice and 120s pause on HTTP 429/403.

## Files
- macOS: functions live in `~/.zshrc` (already in place).
- Windows: [ins_tools.ps1](ins_tools.ps1) (PowerShell functions `Ins-Alias` and `Ins-Download`).
- Install guides: [install.md](install.md), helper script [install.sh](install.sh) (macOS bootstrap), and [install_windows.bat](install_windows.bat) (Windows launcher).

## Quick Start (Windows)
1. Install prerequisites (Python/pip, gallery-dl, optionally ffmpeg) per [install.md](install.md).
2. Place [ins_tools.ps1](ins_tools.ps1) somewhere on disk, e.g. `%USERPROFILE%\Tools\ins_tools.ps1`.
3. Import in PowerShell profile:
   ```powershell
   . "$env:USERPROFILE\Tools\ins_tools.ps1"
   ```
4. Use commands:
   - `Ins-Alias add alice real_username`
   - `Ins-Alias list`
   - `Ins-Download https://www.instagram.com/p/POSTID/ -Limit` (defaults to 5 per post when -Limit is present without value)
   - `Ins-Download alice -Top 3 -Limit 10` (alias mode: first 3 posts, total cap 10)

## Quick Start (macOS)
- Already wired in `~/.zshrc`. Usage mirrors Windows names (`ins_alias`, `ins_download`). See help with `ins_download -h`.

## Notes
- Both platforms read/write the same alias file: `~/.ins_aliases`.
- Uses `gallery-dl` with browser cookies; adjust browser/profile as needed (Chrome on macOS, Chrome default profile on Windows in the PowerShell script).

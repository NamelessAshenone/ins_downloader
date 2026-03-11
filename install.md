# Install Guide (macOS and Windows)

## Prerequisites
- Python 3.8+ with pip
- `gallery-dl` (Python package)
- `ffmpeg` (optional, for video muxing)
- Chrome (for cookie-based auth) or provide your own cookies file

Alias file (shared): `~/.ins_aliases`
Download root (default): `~/Pictures/ins_pictures`

---
## macOS
1. Python & pip: install via Homebrew if missing
   ```bash
   brew install python
   ```
2. Install gallery-dl (user scope):
   ```bash
   pip3 install --user gallery-dl
   ```
3. (Optional) ffmpeg:
   ```bash
   brew install ffmpeg
   ```
4. Ensure `~/.zshrc` already contains `ins_alias` / `ins_download` (current setup). Restart shell.
5. Test:
   ```bash
   ins_download -h
   ```

## Windows
1. Python & pip: install from https://www.python.org/ (add to PATH).
2. Install gallery-dl:
   ```powershell
   python -m pip install --user gallery-dl
   ```
3. (Optional) ffmpeg:
   - Using winget: `winget install --id Gyan.FFmpeg` (or another distro)
   - Ensure `ffmpeg.exe` is on PATH.
4. Place `ins_tools.ps1` somewhere, e.g. `%USERPROFILE%\Tools\ins_tools.ps1`.
5. Add to PowerShell profile (create if missing):
   ```powershell
   if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
   Add-Content -Path $PROFILE -Value ". `$env:USERPROFILE\Tools\ins_tools.ps1" | Out-Null
   ```
   Then restart PowerShell or `.` source it: `. "$env:USERPROFILE\Tools\ins_tools.ps1"`
6. Test:
   ```powershell
   Ins-Download -h
   ```

## Auth / Cookies
- Default is Chrome cookies. If you use another profile on Windows, set `$env:INS_CHROME_PROFILE` before running (see script).
- For strict environments, you can pass `--cookies` to gallery-dl via custom args in the script if you extend it.

## Safety / Anti-scrape
- Random per-request sleep (1–5s) enabled by default.
- On HTTP 429/403, the script notifies and sleeps 120s before finishing.

## Update
- To update gallery-dl:
  ```bash
  pip install --user -U gallery-dl
  ```

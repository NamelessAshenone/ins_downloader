# Instagram Download Helpers

Small helper functions to download Instagram media via [gallery-dl](https://github.com/mikf/gallery-dl), with **alias management** and **post/media limiting**.  
Supports **macOS** (zsh) and **Windows** (PowerShell).

---

## Features

| Feature | Description |
|---------|-------------|
| **Alias mapping** | Map short names to Instagram usernames (`~/.ins_aliases`, shared across platforms) |
| **Download modes** | By URL, username, or alias |
| **Limits** | `-Top N` for first N posts/media; `-Limit [N]` for per-post or total cap |
| **Anti-scrape** | Random 1–5 s sleep per request; auto 120 s backoff on HTTP 429/403 |

---

## Prerequisites

- **Python 3.8+** with pip
- **[gallery-dl](https://github.com/mikf/gallery-dl)** — `pip install --user gallery-dl`
- **ffmpeg** *(optional, for video muxing)*
- **Chrome** *(for cookie-based authentication)*

---

## Quick Start — Windows

### Automated Install (recommended)

1. Double-click **`install_windows.bat`** — it launches the interactive PowerShell installer automatically.  
   *(The script tries `pwsh` first; falls back to `powershell`.)*

2. The installer will walk you through each step:
   - Install / check Python (winget)
   - Install / upgrade gallery-dl (pip)
   - Optionally install ffmpeg (winget)
   - Copy `ins_tools.ps1` to a chosen directory (default `%USERPROFILE%\Tools`)
   - **Set the execution policy to `RemoteSigned`** (so PowerShell can load `ins_tools.ps1` on every session)
   - Optionally add a dot-source line to your PowerShell profile

3. **Restart PowerShell**, then verify:
   ```powershell
   Ins-Download -Help
   ```

> **Execution-policy troubleshooting**  
> If you still see *"cannot be loaded because running scripts is disabled"* or *"not digitally signed"*,  
> open PowerShell **as your normal user** and run:  
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```  
> Then restart PowerShell. This only needs to be done once.

### Manual Install

```powershell
# 1. Install gallery-dl
python -m pip install --user -U gallery-dl

# 2. (Optional) Install ffmpeg
winget install --id Gyan.FFmpeg

# 3. Copy ins_tools.ps1 to a permanent location and unblock it
Copy-Item ins_tools.ps1 "$env:USERPROFILE\Tools\ins_tools.ps1"
Unblock-File "$env:USERPROFILE\Tools\ins_tools.ps1"

# 4. Allow PowerShell to run local scripts (once per user)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 5. Add to your PowerShell profile so it loads on every session
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
Add-Content -Path $PROFILE -Value '. "$env:USERPROFILE\Tools\ins_tools.ps1"'

# 6. Restart PowerShell and verify
Ins-Download -Help
```

> **Why are steps 3–4 needed?**  
> By default Windows PowerShell blocks all scripts.  
> `RemoteSigned` allows scripts created locally to run without a signature, while scripts downloaded from the internet must still be signed.  
> `Unblock-File` (step 3) removes the "downloaded from internet" mark so that `RemoteSigned` treats the file as local.

---

## Quick Start — macOS

```bash
# One-time bootstrap (installs Python, gallery-dl, ffmpeg)
bash install.sh

# Functions are sourced from ~/.zshrc — restart your shell, then:
ins_download -h
```

---

## Usage

### Alias Management

```powershell
Ins-Alias add alice real_username   # create alias
Ins-Alias list                      # show all aliases
Ins-Alias search alice              # search aliases
Ins-Alias delete alice              # remove alias
```

### Downloading

```powershell
# Download a single post (all media)
Ins-Download https://www.instagram.com/p/POSTID/

# Download first 3 media from a post
Ins-Download https://www.instagram.com/p/POSTID/ -Top 3

# Download by alias (first 20 posts by default)
Ins-Download alice

# Alias mode: first 5 posts, total cap 10
Ins-Download alice -Top 5 -Limit 10

# Show help
Ins-Download -Help
```

### Parameters

| Parameter | URL mode | User/Alias mode |
|-----------|----------|-----------------|
| `-Top N` | First N media in the post | First N posts |
| `-Limit [N]` | Per-post cap (default 5 if omitted) | Total cap (default 20) |
| `-Only` | Download only current media (img_index) | — |
| `-Include` | Range like `1,3` or `2-4` | — |
| `-Exclude` | Range like `1,3` or `2-4` | — |

---

## Files

| File | Purpose |
|------|---------|
| `ins_tools.ps1` | PowerShell functions (`Ins-Alias`, `Ins-Download`) |
| `install_windows.bat` | Windows one-click installer launcher |
| `install_windows.ps1` | Interactive Windows installer script |
| `install.sh` | macOS bootstrap script |

---

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `INS_ALIAS_FILE` | `~/.ins_aliases` | Path to alias file |
| `INS_DOWNLOAD_DIR` | `~/Pictures/ins_pictures` | Download root directory |
| `INS_CHROME_PROFILE` | `Default` | Chrome profile name for cookies |

---

## Notes

- Both platforms share the same alias file (`~/.ins_aliases`).
- Uses Chrome cookies for authentication by default. Set `$env:INS_CHROME_PROFILE` to use a different Chrome profile.
- To update gallery-dl: `pip install --user -U gallery-dl`

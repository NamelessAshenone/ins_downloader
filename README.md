# Instagram Download Helpers

Small helper functions to download Instagram media via [gallery-dl](https://github.com/mikf/gallery-dl), with **alias management**, **post/media limiting**, and **configurable download directories**.  
Supports **macOS** (zsh / bash) and **Windows** (PowerShell).

---

## Features

| Feature | Description |
|---------|-------------|
| **Alias mapping** | Map short names to Instagram usernames (`~/.ins_aliases`, shared across platforms) |
| **Download modes** | By URL, username, or alias |
| **Limits** | `-Top N` for first N posts/media; `-Limit [N]` for per-post or total cap |
| **Directory control** | Set a persistent default directory, or specify a per-download directory |
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

> **"Ins-Download" is not recognized / 无法将"Ins-Download"项识别为 …**  
> The script **must be dot-sourced** (note the leading `. `) so that functions
> are loaded into your current session.  Running with
> `powershell -File ins_tools.ps1` executes the script in a child process whose
> scope is discarded immediately, so no functions remain.
>
> ```powershell
> # ✗ Wrong – functions are lost after the script exits
> powershell -ExecutionPolicy Bypass -File "ins_tools.ps1"
>
> # ✓ Correct – functions stay in the current session
> . "C:\path\to\ins_tools.ps1"
> ```
>
> If you followed the installer and accepted the profile entry, just **restart
> PowerShell** — the dot-source line in `$PROFILE` loads the functions
> automatically.

> **Execution-policy troubleshooting**  
> If you still see *"cannot be loaded because running scripts is disabled"* or *"not digitally signed"*,  
> make sure you have done **both** of the following:
>
> 1. **Unblock the script** — files downloaded from the internet carry a Zone.Identifier mark that
>    Windows treats as untrusted. Remove it with:
>    ```powershell
>    Unblock-File "$env:USERPROFILE\Tools\ins_tools.ps1"
>    ```
> 2. **Set the execution policy** to at least `RemoteSigned` for the current user:
>    ```powershell
>    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
>    ```
>
> Both steps are required. `Unblock-File` alone is not enough without `RemoteSigned`,
> and `RemoteSigned` alone will still block files that have the internet zone mark.
> After completing both steps, restart PowerShell.

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
# One-time bootstrap (installs Python, gallery-dl, ffmpeg, copies ins_tools.sh)
bash install.sh

# The installer adds a source line to ~/.zshrc (or ~/.bashrc).
# Restart your shell, then:
ins_download -h
```

---

## Usage

### Download Directory

On first download (when no default directory has been set and no `-Directory` is given), you will be prompted to choose a download directory.  
Press Enter to accept the safe default (`~/Pictures/ins_pictures`), or type a custom path. The choice is persisted to `~/.ins_download_dir`.

You can also set or change the default directory at any time:

```powershell
# Windows
Ins-SetDir "D:\Media\Instagram"

# macOS / Linux
ins_setdir ~/Media/Instagram
```

To see the current directory without changing it, run `Ins-SetDir` / `ins_setdir` with no arguments.

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

# Download to a specific directory
Ins-Download https://www.instagram.com/p/POSTID/ -Directory "D:\MyMedia"
# macOS: ins_download https://www.instagram.com/p/POSTID/ -d ~/MyMedia

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
| `-Directory` / `-d` | Custom output directory | Custom output directory |
| `-Top N` / `-t N` | First N media in the post | First N posts |
| `-Limit [N]` / `-l [N]` | Per-post cap (default 5 if omitted) | Total cap (default 20) |
| `-Only` / `-o` | Download only current media (img_index) | — |
| `-Include` / `-i` | Range like `1,3` or `2-4` | — |
| `-Exclude` / `-e` | Range like `1,3` or `2-4` | — |

> **Note:** Short flags (`-t`, `-l`, `-o`, `-i`, `-e`, `-d`) are for macOS / Linux only.  
> Windows PowerShell uses the long names (`-Top`, `-Limit`, `-Only`, `-Include`, `-Exclude`, `-Directory`).

---

## Files

| File | Purpose |
|------|---------|
| `ins_tools.ps1` | PowerShell functions (`Ins-Alias`, `Ins-Download`, `Ins-SetDir`) |
| `ins_tools.sh` | Shell functions for macOS / Linux (`ins_alias`, `ins_download`, `ins_setdir`) |
| `install_windows.bat` | Windows one-click installer launcher |
| `install_windows.ps1` | Interactive Windows installer script |
| `install.sh` | macOS / Linux bootstrap script |

---

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `INS_ALIAS_FILE` | `~/.ins_aliases` | Path to alias file |
| `INS_DOWNLOAD_DIR` | *(prompted on first use)* | Download root directory (overrides persisted config) |
| `INS_CHROME_PROFILE` | `Default` | Chrome profile name for cookies |

The download directory is resolved in this order:

1. `$env:INS_DOWNLOAD_DIR` (environment variable — highest priority)
2. `~/.ins_download_dir` (persisted by `Ins-SetDir` / `ins_setdir`)
3. First-time prompt (asks you to choose; defaults to `~/Pictures/ins_pictures` if skipped)

---

## Notes

- Both platforms share the same alias file (`~/.ins_aliases`) and config file (`~/.ins_download_dir`).
- Uses Chrome cookies for authentication by default. Set `$env:INS_CHROME_PROFILE` / `INS_CHROME_PROFILE` to use a different Chrome profile.
- To update gallery-dl: `pip install --user -U gallery-dl`

---

## Troubleshooting — gallery-dl not found

When `gallery-dl` is installed via `pip install --user`, the executable is placed in a
user-specific directory that may not be in your `PATH`:

| OS | Typical path |
|----|-------------|
| Windows | `%APPDATA%\Python\PythonXX\Scripts` |
| macOS / Linux | `~/.local/bin` |

The installer scripts (`install_windows.bat` / `install.sh`) and the runtime scripts
(`ins_tools.ps1` / `ins_tools.sh`) will **automatically** detect this directory and add
it to your session `PATH`. If you still see the error, you can add it manually:

**Windows (PowerShell):**
```powershell
# Find the directory
python -m site --user-base
# Example output: C:\Users\You\AppData\Roaming\Python\Python311

# Add its Scripts subdirectory to your user PATH permanently
$base = (python -m site --user-base).Trim()
$scripts = Join-Path $base 'Scripts'
$current = [Environment]::GetEnvironmentVariable('PATH', 'User')
[Environment]::SetEnvironmentVariable('PATH', "$scripts;$current", 'User')
```

**macOS / Linux:**
```bash
# Find the directory
python3 -m site --user-base
# Example output: /home/you/.local

# Add to your shell config (e.g. ~/.zshrc or ~/.bashrc)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

After making changes, **restart your shell** for the new `PATH` to take effect.

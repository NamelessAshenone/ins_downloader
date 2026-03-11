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
> 推荐直接运行脚本：`install_windows.ps1`（见下）。脚本会逐步询问，支持跳过每一项。

### 自动安装（交互式脚本）
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
cd %USERPROFILE%\VSCodeProjects\ins_download
./install_windows.ps1
```
脚本会：
- 检查/安装 Python（winget）
- 安装/升级 gallery-dl（pip --user）
- 询问是否安装 ffmpeg（winget，可跳过）
- 询问是否复制 `ins_tools.ps1` 到指定目录（默认 `%USERPROFILE%\Tools`，可跳过）
- 询问是否自动写入 PowerShell Profile 引用（可跳过，并提示手动添加位置）

### 手动安装步骤
1. Python & pip: 安装并加入 PATH（https://www.python.org/）。
2. gallery-dl:
   ```powershell
   python -m pip install --user -U gallery-dl
   ```
3. (可选) ffmpeg:
   ```powershell
   winget install --id Gyan.FFmpeg
   ```
   确认 `ffmpeg.exe` 在 PATH。
4. 将 `ins_tools.ps1` 放到某个路径，如 `%USERPROFILE%\Tools\ins_tools.ps1`。
5. 写入 PowerShell profile（手动）：
   ```powershell
   if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
   Add-Content -Path $PROFILE -Value ". `$env:USERPROFILE\Tools\ins_tools.ps1""
   ```
   重启 PowerShell，或执行 `. "$env:USERPROFILE\Tools\ins_tools.ps1"`。
6. 验证：
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

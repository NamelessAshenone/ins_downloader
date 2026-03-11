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

## Windows（一键安装）

只需两步：**下载 zip → 运行脚本**，即可完成全部环境配置。

### 快速安装
1. 下载 `ins_download.zip` 并解压到任意目录
2. 右键 **以管理员身份打开 PowerShell**（或普通 PowerShell），进入解压目录，执行：
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
   .\install_windows.ps1
   ```
3. 按照提示操作，每一步均可跳过（输入 `n` 或 `skip`），脚本会提示默认值

脚本会自动完成：
| 步骤 | 说明 | 可跳过 | 默认行为 |
|------|------|--------|----------|
| 1. Python | 检测 Python，未找到则通过 winget 安装 | ✅ | 自动安装 Python 3.12 |
| 2. gallery-dl | 通过 pip 安装核心下载引擎 | ✅ | pip install --user gallery-dl |
| 3. ffmpeg | 可选，视频合并用 | ✅ | 默认跳过 |
| 4. ins_tools.ps1 | 复制脚本到指定目录 | ✅ | `%USERPROFILE%\Tools\ins_tools.ps1` |
| 5. Profile | 写入 PowerShell 自启动配置 | ✅ | 写入 `$PROFILE` |

安装完成后重启 PowerShell 即可使用。

### 默认配置
| 配置项 | 默认值 | 环境变量 |
|--------|--------|----------|
| 别名文件 | `%USERPROFILE%\.ins_aliases` | `INS_ALIAS_FILE` |
| 下载目录 | `%USERPROFILE%\Pictures\ins_pictures` | `INS_DOWNLOAD_DIR` |
| Chrome Profile | `Default` | `INS_CHROME_PROFILE` |

### 手动安装（备选）
如果不想使用一键脚本，也可以手动安装：
1. 安装 Python 3.8+（https://www.python.org/ ，安装时勾选 **Add to PATH**）
2. 安装 gallery-dl：`python -m pip install --user -U gallery-dl`
3. (可选) 安装 ffmpeg：`winget install --id Gyan.FFmpeg`
4. 将 `ins_tools.ps1` 放到 `%USERPROFILE%\Tools\` 目录
5. 在 PowerShell Profile 中添加：`. "$env:USERPROFILE\Tools\ins_tools.ps1"`
6. 重启 PowerShell，验证：`Ins-Download -Help`

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

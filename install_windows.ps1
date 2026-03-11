# ============================================================
#  ins_download Windows 一键安装脚本
#  用户只需下载 zip 并运行此脚本，即可自动完成全部环境配置
#  每一步均可跳过（skip），默认路径会明确提示
# ============================================================

$ErrorActionPreference = 'Stop'

# ---- helper: yes/no prompt ----
function Prompt-YesNo {
    param([string]$Message, [switch]$DefaultYes)
    $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $resp = Read-Host "$Message $suffix"
    if ([string]::IsNullOrWhiteSpace($resp)) { return [bool]$DefaultYes }
    return $resp.Trim().ToLower() -eq 'y'
}

# ---- helper: refresh PATH in current session ----
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

# ---- helper: locate python.exe ----
function Find-Python {
    # 1. already in PATH
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # 2. common install locations
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Python\Python*\python.exe",
        "$env:ProgramFiles\Python*\python.exe",
        "$env:ProgramFiles(x86)\Python*\python.exe"
    )
    foreach ($pattern in $candidates) {
        $found = Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

# ---- helper: ensure a directory exists in user PATH ----
function Ensure-InUserPath {
    param([string]$Dir)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -and ($userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }) -contains $Dir.TrimEnd('\')) { return }
    $newPath = if ($userPath) { "$userPath;$Dir" } else { $Dir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Refresh-Path
    Write-Host "  [PATH] 已将 $Dir 写入用户 PATH 环境变量"
}

# ============================================================
#  STEP 0 : 欢迎信息
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ins_download Windows 一键安装脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "本脚本将自动完成以下步骤："
Write-Host "  1. 检查并安装 Python（如缺失）"
Write-Host "  2. 安装/升级 gallery-dl（核心下载引擎）"
Write-Host "  3. 安装 ffmpeg（可选，用于视频合并）"
Write-Host "  4. 将 ins_tools.ps1 复制到指定目录"
Write-Host "  5. 配置 PowerShell Profile 自动加载脚本"
Write-Host ""
Write-Host "每一步都可以输入 'skip' 或选择 'n' 跳过。" -ForegroundColor Yellow
Write-Host ""

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$summary = @()

# ============================================================
#  STEP 1 : Python
# ============================================================
Write-Host "--------------------------------------------" -ForegroundColor DarkGray
Write-Host "[1/5] 检查 Python ..." -ForegroundColor Green

$pythonExe = Find-Python
if ($pythonExe) {
    $pyVer = & $pythonExe --version 2>&1
    Write-Host "  已检测到 Python: $pythonExe ($pyVer)"
    $summary += "Python: 已存在 ($pyVer)"
} else {
    Write-Host "  未检测到 Python。" -ForegroundColor Yellow
    Write-Host "  默认操作: 通过 winget 安装 Python 3"
    Write-Host "  如需跳过，请输入 n（需要自行安装 Python 并确保在 PATH 中）" -ForegroundColor Yellow
    if (Prompt-YesNo "是否自动安装 Python?" -DefaultYes) {
        $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
        if ($hasWinget) {
            Write-Host "  正在通过 winget 安装 Python ..."
            winget install --id Python.Python.3.12 -e --source winget --accept-package-agreements --accept-source-agreements
            Refresh-Path
            $pythonExe = Find-Python
            if ($pythonExe) {
                Write-Host "  Python 安装成功: $pythonExe"
                $summary += "Python: 已自动安装"
            } else {
                Write-Host "  安装后仍未检测到 Python，请手动确认安装并添加到 PATH 后重新运行本脚本。" -ForegroundColor Red
                $summary += "Python: 安装后未检测到（需手动处理）"
            }
        } else {
            Write-Host "  未检测到 winget，请手动安装 Python: https://www.python.org/downloads/" -ForegroundColor Red
            Write-Host "  安装时请勾选 'Add Python to PATH'" -ForegroundColor Yellow
            $summary += "Python: 需手动安装（无 winget）"
        }
    } else {
        Write-Host "  已跳过 Python 安装。请自行确保 python 在 PATH 中。"
        $summary += "Python: 用户跳过"
    }
    # re-check
    if (-not $pythonExe) { $pythonExe = Find-Python }
}

# ============================================================
#  STEP 2 : gallery-dl
# ============================================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor DarkGray
Write-Host "[2/5] 安装/升级 gallery-dl ..." -ForegroundColor Green

if (-not $pythonExe) {
    Write-Host "  Python 不可用，跳过 gallery-dl 安装。请安装 Python 后重新运行。" -ForegroundColor Red
    $summary += "gallery-dl: 跳过（无 Python）"
} else {
    Write-Host "  默认操作: 通过 pip 安装到用户目录（--user）"
    Write-Host "  如需跳过，请输入 n" -ForegroundColor Yellow
    if (Prompt-YesNo "是否安装/升级 gallery-dl?" -DefaultYes) {
        & $pythonExe -m pip install --user -U gallery-dl
        # ensure Scripts dir in PATH
        $scriptsDir = Join-Path (Split-Path $pythonExe) 'Scripts'
        if (-not (Test-Path $scriptsDir)) {
            # user-install location
            $scriptsDir = & $pythonExe -c "import site; print(site.getusersitepackages())" 2>$null
            if ($scriptsDir) { $scriptsDir = Join-Path (Split-Path $scriptsDir) 'Scripts' }
        }
        if ($scriptsDir -and (Test-Path $scriptsDir)) {
            Ensure-InUserPath $scriptsDir
        }
        Write-Host "  gallery-dl 安装/升级完成"
        $summary += "gallery-dl: 已安装/升级"
    } else {
        Write-Host "  已跳过 gallery-dl。如需手动安装: python -m pip install --user -U gallery-dl"
        $summary += "gallery-dl: 用户跳过"
    }
}

# ============================================================
#  STEP 3 : ffmpeg (可选)
# ============================================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor DarkGray
Write-Host "[3/5] 检查 ffmpeg（可选，用于视频合并）..." -ForegroundColor Green

if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    Write-Host "  已检测到 ffmpeg。"
    $summary += "ffmpeg: 已存在"
} else {
    Write-Host "  未检测到 ffmpeg。这是可选组件，不安装也不影响图片下载。" -ForegroundColor Yellow
    Write-Host "  默认操作: 跳过。如需安装请输入 y" -ForegroundColor Yellow
    if (Prompt-YesNo "是否通过 winget 安装 ffmpeg?") {
        $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
        if ($hasWinget) {
            winget install --id Gyan.FFmpeg -e --source winget --accept-package-agreements --accept-source-agreements
            Refresh-Path
            Write-Host "  ffmpeg 安装完成"
            $summary += "ffmpeg: 已自动安装"
        } else {
            Write-Host "  未检测到 winget，请手动安装 ffmpeg: https://ffmpeg.org/download.html" -ForegroundColor Red
            $summary += "ffmpeg: 需手动安装（无 winget）"
        }
    } else {
        Write-Host "  已跳过 ffmpeg。"
        $summary += "ffmpeg: 用户跳过"
    }
}

# ============================================================
#  STEP 4 : 复制 ins_tools.ps1
# ============================================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor DarkGray
Write-Host "[4/5] 放置 ins_tools.ps1 ..." -ForegroundColor Green

$defaultToolsDir = Join-Path $env:USERPROFILE 'Tools'
$scriptDst = $null

Write-Host "  默认路径: $defaultToolsDir\ins_tools.ps1" -ForegroundColor Yellow
Write-Host "  你可以:"
Write-Host "    - 直接按回车使用默认路径"
Write-Host "    - 输入自定义目录路径"
Write-Host "    - 输入 'skip' 跳过此步骤（ins_tools.ps1 将保留在当前目录: $repoRoot）"

$targetDir = Read-Host "  请输入目标目录"

if ($targetDir.Trim().ToLower() -eq 'skip') {
    Write-Host "  已跳过。ins_tools.ps1 位于: $repoRoot\ins_tools.ps1"
    $scriptDst = Join-Path $repoRoot 'ins_tools.ps1'
    $summary += "ins_tools.ps1: 保留在原位 ($scriptDst)"
} else {
    if ([string]::IsNullOrWhiteSpace($targetDir)) { $targetDir = $defaultToolsDir }
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-Host "  已创建目录: $targetDir"
    }
    $src = Join-Path $repoRoot 'ins_tools.ps1'
    $scriptDst = Join-Path $targetDir 'ins_tools.ps1'
    Copy-Item -Path $src -Destination $scriptDst -Force
    Write-Host "  已复制到: $scriptDst"
    $summary += "ins_tools.ps1: $scriptDst"
}

# ============================================================
#  STEP 5 : PowerShell Profile
# ============================================================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor DarkGray
Write-Host "[5/5] 配置 PowerShell Profile 自动加载 ..." -ForegroundColor Green

$dotSourceLine = if ($scriptDst) { ". `"$scriptDst`"" } else { $null }

if (-not $scriptDst) {
    Write-Host "  ins_tools.ps1 未部署，跳过 Profile 配置。"
    $summary += "Profile: 跳过（无脚本路径）"
} else {
    Write-Host "  默认操作: 将以下内容写入 PowerShell Profile，使每次打开终端自动加载功能" -ForegroundColor Yellow
    Write-Host "    $dotSourceLine" -ForegroundColor Yellow
    Write-Host "  Profile 路径: $PROFILE" -ForegroundColor Yellow
    Write-Host "  如需跳过请输入 n（之后可手动添加上述内容到 Profile）" -ForegroundColor Yellow
    if (Prompt-YesNo "是否自动写入 PowerShell Profile?" -DefaultYes) {
        if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
        $profileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue
        if ($profileContent -and ($profileContent -contains $dotSourceLine)) {
            Write-Host "  Profile 中已包含该条目，无需重复添加。"
        } else {
            Add-Content -Path $PROFILE -Value $dotSourceLine
            Write-Host "  已写入 Profile。"
        }
        $summary += "Profile: 已配置自动加载"
    } else {
        Write-Host "  已跳过 Profile 配置。如需手动添加，请在 PowerShell 中执行:"
        Write-Host "    Add-Content -Path `$PROFILE -Value '$dotSourceLine'" -ForegroundColor Cyan
        $summary += "Profile: 用户跳过"
    }
}

# ============================================================
#  安装摘要
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  安装摘要" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
foreach ($item in $summary) {
    Write-Host "  - $item"
}
Write-Host ""
Write-Host "后续操作:" -ForegroundColor Green
if ($dotSourceLine) {
    Write-Host "  1. 重启 PowerShell（或执行: $dotSourceLine）"
} else {
    Write-Host "  1. 重启 PowerShell"
}
Write-Host "  2. 验证安装: Ins-Download -Help"
Write-Host "  3. 管理别名: Ins-Alias list"
Write-Host ""
Write-Host "默认配置一览:" -ForegroundColor Green
Write-Host "  别名文件    : $env:USERPROFILE\.ins_aliases"
Write-Host "  下载目录    : $env:USERPROFILE\Pictures\ins_pictures"
Write-Host "  Chrome Profile: Default"
Write-Host "  （以上均可通过环境变量 INS_ALIAS_FILE / INS_DOWNLOAD_DIR / INS_CHROME_PROFILE 自定义）"
Write-Host ""
Write-Host "安装完成！" -ForegroundColor Green
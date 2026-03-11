# Interactive installer for Windows
# - Installs Python (winget) if missing (optional)
# - Installs/updates gallery-dl (pip --user)
# - Optionally installs ffmpeg (winget)
# - Optionally copies ins_tools.ps1 to a chosen folder
# - Optionally appends profile entry to load the script

function Prompt-YesNo {
    param([string]$Message,[switch]$DefaultYes)
    $suffix = $DefaultYes ? "[Y/n]" : "[y/N]"
    $resp = Read-Host "$Message $suffix"
    if ([string]::IsNullOrWhiteSpace($resp)) { return $DefaultYes }
    return $resp.Trim().ToLower() -eq 'y'
}

function Ensure-Python {
    if (Get-Command python -ErrorAction SilentlyContinue) { Write-Host "Python found."; return }
    if (-not (Prompt-YesNo "Python not found. Install via winget?" -DefaultYes:$true)) { Write-Host "Skipped Python install."; return }
    winget install --id Python.Python.3 -e --source winget
}

function Install-GalleryDl {
    Write-Host "Installing/Updating gallery-dl (user scope)..."
    python -m pip install --user -U gallery-dl
}

function Ensure-FFmpeg {
    if (Get-Command ffmpeg -ErrorAction SilentlyContinue) { Write-Host "ffmpeg found."; return }
    if (-not (Prompt-YesNo "ffmpeg not found. Install via winget?" -DefaultYes:$false)) { Write-Host "Skipped ffmpeg."; return }
    winget install --id Gyan.FFmpeg -e --source winget
}

function Copy-InsTools {
    param([string]$RepoRoot)
    $defaultDir = Join-Path $env:USERPROFILE 'Tools'
    $targetDir = Read-Host "Where to place ins_tools.ps1? (Default: $defaultDir; enter 'skip' to skip)"
    if ([string]::IsNullOrWhiteSpace($targetDir)) { $targetDir = $defaultDir }
    if ($targetDir.Trim().ToLower() -eq 'skip') { Write-Host "Skip copy."; return $null }
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    $src = Join-Path $RepoRoot 'ins_tools.ps1'
    $dst = Join-Path $targetDir 'ins_tools.ps1'
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "Copied to $dst"
    return $dst
}

function Update-Profile {
    param([string]$ScriptPath)
    if (-not $ScriptPath) { return }
    if (-not (Prompt-YesNo "Add dot-source to PowerShell profile?" -DefaultYes:$true)) { Write-Host "Skipped profile update. Add manually: . \"$ScriptPath\""; return }
    if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
    $line = ". \"$ScriptPath\""
    $profileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue
    if ($profileContent -contains $line) { Write-Host "Profile already contains entry."; return }
    Add-Content -Path $PROFILE -Value $line
    Write-Host "Profile updated. Restart PowerShell or run: $line"
}

# ---- main ----
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Installer root: $repoRoot"

Ensure-Python
Install-GalleryDl
Ensure-FFmpeg
$scriptPath = Copy-InsTools -RepoRoot $repoRoot
Update-Profile -ScriptPath $scriptPath

Write-Host "All done. Test with: Ins-Download -h"
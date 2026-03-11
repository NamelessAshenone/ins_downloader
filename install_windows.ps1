# Interactive installer for Windows
# - Installs Python (winget) if missing (optional)
# - Installs/updates gallery-dl (pip --user)
# - Optionally installs ffmpeg (winget)
# - Optionally copies ins_tools.ps1 to a chosen folder
# - Optionally appends profile entry to load the script

function Prompt-YesNo {
    param([string]$Message,[switch]$DefaultYes)
    $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
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
    # Ensure the Python user Scripts directory is in the persistent user PATH
    try {
        $pyScriptsDir = & python -c "import sysconfig, os; print(sysconfig.get_path('scripts', f'{os.name}_user'))" 2>$null
        if ($pyScriptsDir) {
            $pyScriptsDir = $pyScriptsDir.Trim()
            if (Test-Path $pyScriptsDir) {
                $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
                if ($currentPath -notlike "*$([regex]::Escape($pyScriptsDir))*") {
                    [Environment]::SetEnvironmentVariable('PATH', "$pyScriptsDir;$currentPath", 'User')
                    $env:PATH = "$pyScriptsDir;$env:PATH"
                    Write-Host "Added $pyScriptsDir to user PATH."
                }
            }
        }
    } catch {
        Write-Host "Warning: Could not add Python Scripts directory to PATH automatically."
        Write-Host "You may need to add it manually. Run:  python -c `"import sysconfig, os; print(sysconfig.get_path('scripts', f'{os.name}_user'))`""
        Write-Host "Then add the printed path to your user PATH environment variable."
    }
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
    Unblock-File -Path $dst -ErrorAction SilentlyContinue
    Write-Host "Copied to $dst"
    return $dst
}

function Ensure-ExecutionPolicy {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -in @('RemoteSigned','Unrestricted','Bypass')) {
        Write-Host "Execution policy (CurrentUser): $policy — OK."
        return
    }
    Write-Host "Current execution policy (CurrentUser): $policy"
    Write-Host "PowerShell will block unsigned scripts (like ins_tools.ps1) unless the policy is at least RemoteSigned."
    if (-not (Prompt-YesNo "Set execution policy to RemoteSigned for the current user?" -DefaultYes:$true)) {
        Write-Host "Skipped. You may need to run the following command manually before ins_tools.ps1 will load:"
        Write-Host "  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
        return
    }
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Write-Host "Execution policy set to RemoteSigned (CurrentUser)."
}

function Update-Profile {
    param([string]$ScriptPath)
    if (-not $ScriptPath) { return }
    if (-not (Prompt-YesNo "Add dot-source to PowerShell profile?" -DefaultYes:$true)) { Write-Host "Skipped profile update. Add manually: . `"$ScriptPath`""; return }
    if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
    $line = ". `"$ScriptPath`""
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
Ensure-ExecutionPolicy
Update-Profile -ScriptPath $scriptPath

Write-Host "All done. Restart PowerShell, then verify with: Ins-Download -Help"
Write-Host "(Do NOT use 'powershell -File' to load ins_tools.ps1 — it must be dot-sourced.)"
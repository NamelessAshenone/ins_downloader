# PowerShell helpers for Instagram downloads (Windows)
# Mirrors macOS ins_alias / ins_download behavior

# Guard: this script must be dot-sourced so that functions are defined in the
# caller's session.  Running with "powershell -File" or directly executing the
# script starts a child process whose scope is discarded when it exits, which
# means Ins-Download / Ins-Alias will not be available afterward.
if ($MyInvocation.InvocationName -ne '.') {
    Write-Warning "This script needs to be dot-sourced, not executed directly."
    Write-Warning "Run the following command instead:"
    Write-Warning "  . `"$($MyInvocation.MyCommand.Path)`""
    Write-Warning ""
    Write-Warning "To load it automatically in every PowerShell session, add that"
    Write-Warning "line to your profile (`$PROFILE)."
    return
}

# Configurable defaults
$Global:InsAliasFile     = if ($env:INS_ALIAS_FILE)     { $env:INS_ALIAS_FILE }     else { "$env:USERPROFILE\.ins_aliases" }
$Global:InsChromeProfile = if ($env:INS_CHROME_PROFILE) { $env:INS_CHROME_PROFILE } else { "Default" }
$Global:InsConfigFile    = Join-Path $env:USERPROFILE '.ins_download_dir'
$Global:InsDefaultSafeDir = Join-Path $env:USERPROFILE 'Pictures\ins_pictures'

# Download directory: env var → persisted config file → not yet configured
$Global:InsDownloadDirConfigured = $false
if ($env:INS_DOWNLOAD_DIR) {
    $Global:InsDownloadDir = $env:INS_DOWNLOAD_DIR
    $Global:InsDownloadDirConfigured = $true
} elseif (Test-Path $Global:InsConfigFile) {
    $savedDir = (Get-Content $Global:InsConfigFile -First 1).Trim()
    if ($savedDir) {
        $Global:InsDownloadDir = $savedDir
        $Global:InsDownloadDirConfigured = $true
    }
}

function Ins-Alias {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('add','modify','remove','delete','list','show','search','find')]
        [string]$Action,
        [string]$Alias,
        [string]$RealId
    )

    if (-not (Test-Path $Global:InsAliasFile)) { New-Item -ItemType File -Path $Global:InsAliasFile -Force | Out-Null }

    switch ($Action) {
        { $_ -in 'add','modify' } {
            if ([string]::IsNullOrWhiteSpace($Alias) -or [string]::IsNullOrWhiteSpace($RealId)) { Write-Host "Usage: Ins-Alias add <alias> <real_username>"; return }
            # unique constraint: one real user -> one alias
            $lines = @(Get-Content $Global:InsAliasFile)
            $existingAlias = $lines | Where-Object { $_ -match "^.+\s+$RealId$" } | ForEach-Object { ($_ -split '\s+')[0] }
            if ($existingAlias -and $existingAlias -ne $Alias) {
                $resp = Read-Host "User @$RealId already has alias [$existingAlias]. Overwrite with [$Alias]? (y/n)"
                if ($resp -notin @('y','Y')) { Write-Host "Cancelled."; return }
                $lines = @($lines | Where-Object { $_ -notmatch "\s+$RealId$" })
            }
            $lines = @($lines | Where-Object { $_ -notmatch "^$Alias\s+" })
            $lines += "$Alias $RealId"
            $lines | Set-Content $Global:InsAliasFile
            Write-Host "Saved: $Alias -> @$RealId"
        }
        { $_ -in 'remove','delete' } {
            if ([string]::IsNullOrWhiteSpace($Alias)) { Write-Host "Usage: Ins-Alias delete <alias>"; return }
            $lines = Get-Content $Global:InsAliasFile
            Set-Content -Path $Global:InsAliasFile -Value ($lines | Where-Object { $_ -notmatch "^$Alias\s+" })
            Write-Host "Deleted alias $Alias"
        }
        { $_ -in 'list','show' } {
            Write-Host "Aliases in $Global:InsAliasFile"
            Get-Content $Global:InsAliasFile | Sort-Object | ForEach-Object {
                if ($_ -match "^(\S+)\s+(\S+)$") { '{0,-15} {1}' -f $matches[1], $matches[2] }
            }
        }
        { $_ -in 'search','find' } {
            if ([string]::IsNullOrWhiteSpace($Alias)) { Write-Host "Usage: Ins-Alias search <keyword>"; return }
            Write-Host "Searching: $Alias"
            Get-Content $Global:InsAliasFile | Select-String -Pattern $Alias -SimpleMatch | ForEach-Object {
                if ($_.Line -match "^(\S+)\s+(\S+)$") { '{0,-15} {1}' -f $matches[1], $matches[2] }
            }
        }
    }
}

function Ins-SetDir {
    param(
        [Parameter(Position=0)][string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        if ($Global:InsDownloadDirConfigured) {
            Write-Host "Current download directory: $Global:InsDownloadDir"
        } else {
            Write-Host "No download directory configured yet."
        }
        Write-Host "Usage: Ins-SetDir <path>"
        return
    }
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not (Test-Path $resolved)) { New-Item -ItemType Directory -Force -Path $resolved | Out-Null }
    $Global:InsDownloadDir = $resolved
    $Global:InsDownloadDirConfigured = $true
    Set-Content -Path $Global:InsConfigFile -Value $resolved
    Write-Host "Download directory set to: $resolved"
}

function Ins-Download {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)][string]$Target,
        [Parameter(Position=1)][string]$Directory,
        [int]$Top,
        [Nullable[int]]$Limit,
        [switch]$Only,
        [string]$Include,
        [string]$Exclude,
        [switch]$Help
    )

    if ($Help -or [string]::IsNullOrWhiteSpace($Target)) {
        Write-Host "Usage: Ins-Download <URL|alias|username> [-Directory dir] [-Top N] [-Limit [N]] [-Only] [-Include spec] [-Exclude spec]"
        Write-Host "-Directory: custom output directory for this download (also accepts positional after target)"
        Write-Host "-Top: URL mode -> first N media in the post; user/alias -> first N posts"
        Write-Host "-Limit: URL mode -> per-post cap when provided (default 5 if value omitted); user/alias -> total cap (default 20)"
        Write-Host "-Only: URL mode, download only current media (uses img_index)"
        Write-Host "-Include/-Exclude: ranges like 1,3 or 2-4 (URL mode)"
        return
    }

    $aliasMap = @{}
    if (Test-Path $Global:InsAliasFile) {
        Get-Content $Global:InsAliasFile | ForEach-Object {
            if ($_ -match "^(\S+)\s+(\S+)$") { $aliasMap[$matches[1]] = $matches[2] }
        }
    }

    $mode = if ($Target -like 'http*') { 'url' } else { 'user' }
    $realUser = ''
    $currentAlias = ''

    if ($mode -eq 'url') {
        $cleanUrl = $Target -replace "\?.*", ''
        $Target = $cleanUrl
    } else {
        if ($aliasMap.ContainsKey($Target)) {
            $currentAlias = $Target
            $realUser = $aliasMap[$Target]
        } else {
            $realUser = $Target
        }
        $Target = "https://www.instagram.com/$realUser/"
    }

    # First-time directory prompt when no -Directory specified and no default configured
    if (-not $Directory -and -not $Global:InsDownloadDirConfigured) {
        Write-Host "No default download directory has been configured."
        $userDir = Read-Host "Enter a download directory path (or press Enter to use default: $($Global:InsDefaultSafeDir))"
        if ([string]::IsNullOrWhiteSpace($userDir)) {
            $Global:InsDownloadDir = $Global:InsDefaultSafeDir
            Write-Host "Using default directory: $($Global:InsDefaultSafeDir)"
        } else {
            $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($userDir)
            $Global:InsDownloadDir = $resolved
            Write-Host "Download directory set to: $resolved"
        }
        $Global:InsDownloadDirConfigured = $true
        Set-Content -Path $Global:InsConfigFile -Value $Global:InsDownloadDir
    }

    $folderName = if ($realUser) { $realUser } else { 'unknown' }
    $targetDir = if ($Directory) { $Directory } elseif ($currentAlias) { Join-Path $Global:InsDownloadDir $currentAlias } else { Join-Path $Global:InsDownloadDir $folderName }
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }

    $gdlArgs = @(
        '--cookies-from-browser', "chrome:$($Global:InsChromeProfile)",
        '-d', $targetDir,
        '-o', 'directory=[]',
        '-o', ('filename=' + ($(if ($currentAlias) { "$currentAlias" } else { '{username}' }) + '_{date:%Y%m%d_%H%M}_{num}.{extension}')),
        '--retries', '10',
        '-o', 'http.timeout=60',
        '--sleep', '1-5',
        '-o', 'write-info-json=true',
        '-o', 'download.clobber=numbered'
    )

    if ($mode -eq 'url') {
        if ($Only.IsPresent) {
            if ($Target -match 'img_index=([0-9]+)') { $gdlArgs += @('--range', $matches[1]) } else { $gdlArgs += @('--range', '1') }
        }
        if ($Top) { $gdlArgs += @('--range', "1-$Top") }
        if ($Include) { $gdlArgs += @('--range', $Include) }
        if ($Exclude) {
            if ($Exclude -match '([0-9]+)-([0-9]+)') { $gdlArgs += @('--filter', "num < $($matches[1]) or num > $($matches[2])") }
            else { $gdlArgs += @('--filter', "num != $Exclude") }
        }
        if ($PSBoundParameters.ContainsKey('Limit')) {
            $effective = if ($Limit -gt 0) { $Limit } else { 5 }
            $gdlArgs += @('--filter', "num <= $effective")
        }
    } else {
        $effectiveLimit = if ($PSBoundParameters.ContainsKey('Limit')) { if ($Limit -gt 0) { $Limit } else { 20 } } else { 20 }
        if ($Top) { $gdlArgs += @('--range', "1-$Top") }
        $gdlArgs += @('--filter', "num <= $effectiveLimit")
    }

    $logFile = [System.IO.Path]::GetTempFileName()
    Write-Host "Downloading to $targetDir"
    $proc = Start-Process -FilePath "gallery-dl" -ArgumentList ($gdlArgs + @($Target)) -RedirectStandardOutput $logFile -RedirectStandardError $logFile -NoNewWindow -PassThru
    $proc.WaitForExit()
    $output = Get-Content $logFile
    $output | ForEach-Object { Write-Host $_ }

    if ($output -match 'HTTP error (429|403)') {
        Write-Host "Detected 429/403. Backing off for 120 seconds..."
        Start-Sleep -Seconds 120
    }

    Remove-Item $logFile -ErrorAction SilentlyContinue

    if ($proc.ExitCode -eq 0) { Write-Host "Done" } else { Write-Host "gallery-dl exited with code $($proc.ExitCode)" }
}

Set-Alias -Name ins_alias -Value Ins-Alias
Set-Alias -Name ins_download -Value Ins-Download
Set-Alias -Name ins_setdir -Value Ins-SetDir

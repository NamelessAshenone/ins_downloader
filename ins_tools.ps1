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
$Global:InsAliasFile       = if ($env:INS_ALIAS_FILE)     { $env:INS_ALIAS_FILE }     else { "$env:USERPROFILE\.ins_aliases" }
$Global:InsBrowser         = if ($env:INS_BROWSER)        { $env:INS_BROWSER }        else { "chrome" }
$Global:InsBrowserProfile  = if ($env:INS_BROWSER_PROFILE){ $env:INS_BROWSER_PROFILE} else { if ($env:INS_CHROME_PROFILE) { $env:INS_CHROME_PROFILE } else { "Default" } }
$Global:InsConfigFile      = Join-Path $env:USERPROFILE '.ins_download_dir'
$Global:InsCookieConfFile  = Join-Path $env:USERPROFILE '.ins_cookie_path'
$Global:InsDefaultSafeDir  = Join-Path $env:USERPROFILE 'Pictures\ins_pictures'

# Load bound cookie file if any
$Global:InsCookiesFile = $null
if ($env:INS_COOKIES_FILE) {
    $Global:InsCookiesFile = $env:INS_COOKIES_FILE
} elseif (Test-Path $Global:InsCookieConfFile) {
    $savedCookie = (Get-Content $Global:InsCookieConfFile -First 1).Trim()
    if ($savedCookie) {
        $Global:InsCookiesFile = $savedCookie
    }
}

# Ensure Python user Scripts directory is in PATH (pip --user installs go there)
if (-not (Get-Command gallery-dl -ErrorAction SilentlyContinue)) {
    try {
        # getting actual user Scripts path via sysconfig cross-platform
        $pyScriptsDir = & python -c "import sysconfig, os; print(sysconfig.get_path('scripts', f'{os.name}_user'))" 2>$null
        if ($pyScriptsDir) {
            $pyScriptsDir = $pyScriptsDir.Trim()
            if ((Test-Path $pyScriptsDir) -and $env:PATH -notlike "*$([regex]::Escape($pyScriptsDir))*") {
                $env:PATH = "$pyScriptsDir;$env:PATH"
            }
        }
    } catch {}
}

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

function Ins-SetCookie {
    param(
        [Parameter(Position=0)][string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        if ($Global:InsCookiesFile) {
            Write-Host "Current bound cookies file: $($Global:InsCookiesFile)"
        } else {
            Write-Host "No cookies file currently bound."
        }
        Write-Host "Usage: Ins-SetCookie <path_to_cookies.txt>"
        return
    }
    
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not (Test-Path $resolved -PathType Leaf)) {
        Write-Host "Warning: File does not exist at path: $resolved" -ForegroundColor Yellow
        Write-Host "Make sure you export cookies accurately." -ForegroundColor Yellow
    }
    
    $Global:InsCookiesFile = $resolved
    Set-Content -Path $Global:InsCookieConfFile -Value $resolved
    Write-Host "Cookies file successfully bound to: $resolved" -ForegroundColor Green
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
        Write-Host "-Top: first N media in the post (works equally for URL and User modes)"
        Write-Host "-Limit: URL mode -> per-post cap when provided (default 5); user/alias -> total overall cap (default 20)"
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
        '-d', $targetDir,
        '-o', 'directory=[]',
        '-o', ('filename=' + ($(if ($currentAlias) { "$currentAlias" } else { '{username}' }) + '_{date:%Y%m%d_%H%M}_{num}.{extension}')),
        '--retries', '10',
        '-o', 'http.timeout=60',
        '--sleep', '1-5',
        '-o', 'write-info-json=true',
        '-o', 'download.clobber=numbered'
    )
    
    $usingBrowserCookies = $false
    if ($Global:InsCookiesFile -and (Test-Path $Global:InsCookiesFile)) {
        $gdlArgs = @('--cookies', $Global:InsCookiesFile) + $gdlArgs
    } else {
        $gdlArgs = @('--cookies-from-browser', "$($Global:InsBrowser):$($Global:InsBrowserProfile)") + $gdlArgs
        $usingBrowserCookies = $true
    }

    if ($mode -eq 'url') {
        if ($Only.IsPresent) {
            if ($Target -match 'img_index=([0-9]+)') { $gdlArgs += @('--range', $matches[1]) } else { $gdlArgs += @('--range', '1') }
        }
        if ($Top) { $gdlArgs += @('--range', "1-$Top") }
        if ($Include) { $gdlArgs += @('--range', $Include) }
        if ($Exclude) {
            if ($Exclude -match '([0-9]+)-([0-9]+)') { $gdlArgs += @('--filter', "`"num < $($matches[1]) or num > $($matches[2])`"") }
            else { $gdlArgs += @('--filter', "`"num != $Exclude`"") }
        }
        if ($PSBoundParameters.ContainsKey('Limit')) {
            $effective = if ($Limit -gt 0) { $Limit } else { 5 }
            $gdlArgs += @('--filter', "`"num <= $effective`"")
        }
    } else {
        $effectiveLimit = if ($PSBoundParameters.ContainsKey('Limit')) { if ($Limit -gt 0) { $Limit } else { 20 } } else { 20 }
        
        # User mode logic reversed from URL mode to meet total-cap requirement:
        # -Limit limits the total items downloaded across all posts
        $gdlArgs += @('--range', "1-$effectiveLimit")
        
        # -Top limits the number of media per post (carousels)
        if ($Top) { $gdlArgs += @('--filter', "`"num <= $Top`"") }
    }

    $gdlCmd = Get-Command gallery-dl -ErrorAction SilentlyContinue
    if (-not $gdlCmd) {
        Write-Host "Error: gallery-dl not found. Install it with:  python -m pip install --user -U gallery-dl"
        Write-Host "Then restart your PowerShell session so the updated PATH takes effect."
        return
    }
    $gdlPath = $gdlCmd.Source

    $fullArgs = @()
    foreach ($arg in ($gdlArgs + @($Target))) {
        # If argument contains spaces, wrap it in double quotes (only if it's not already)
        if ($arg -match "\s" -or $arg -match '==|<=|>=|!=|<|>') {
            $cleanArg = $arg -replace '^"|"$', ''
            $fullArgs += "`"$cleanArg`""
        } else {
            $fullArgs += $arg
        }
    }
    
    $argString = $fullArgs -join ' '

    $stdoutLog = [System.IO.Path]::GetTempFileName()
    $stderrLog = [System.IO.Path]::GetTempFileName()
    Write-Host "Downloading to $targetDir"
    $proc = Start-Process -FilePath $gdlPath -ArgumentList $argString -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -NoNewWindow -PassThru
    if (-not $proc) {
        Write-Host "Error: failed to start gallery-dl at $gdlPath"
        Remove-Item $stdoutLog, $stderrLog -ErrorAction SilentlyContinue
        return
    }
    $proc.WaitForExit()
    $output = @(Get-Content $stdoutLog -ErrorAction SilentlyContinue) + @(Get-Content $stderrLog -ErrorAction SilentlyContinue)
    $output | ForEach-Object { Write-Host $_ }

    if ($output -match 'HTTP error (429|403)') {
        Write-Host "Detected 429/403. Backing off for 120 seconds..."
        Start-Sleep -Seconds 120
    }
    
    $needsCookiePrompt = $false

    if ($output -match 'Permission denied.*Cookies') {
        Write-Host "`n[!]" -ForegroundColor Red -NoNewline
        Write-Host " ERROR: Chrome cookie database is locked!" -ForegroundColor Yellow
        Write-Host "Please CLOSE all Google Chrome windows completely so gallery-dl can read your Instagram login cookies.`n" -ForegroundColor Cyan
        $needsCookiePrompt = $true
    }
    
    if ($output -match 'Failed to decrypt cookie \(DPAPI\)') {
        Write-Host "`n[!]" -ForegroundColor Red -NoNewline
        Write-Host " ERROR: Browser App-Bound Encryption blocked cookie decryption!" -ForegroundColor Yellow
        Write-Host "Since Chrome 114+ (and recently Edge), third-party tools cannot decrypt cookies directly." -ForegroundColor Cyan
        $needsCookiePrompt = $true
    }

    if ($needsCookiePrompt -and $usingBrowserCookies) {
        Write-Host "`n[WORKAROUND needed]" -ForegroundColor Magenta
        Write-Host "1. Install 'Get cookies.txt LOCALLY' extension in your browser."
        Write-Host "2. Go to Instagram and click the extension to export your cookies as a text file."
        Write-Host "3. Input the path to that text file below to bind it automatically."
        $cookiePath = Read-Host "`nEnter the path to your cookies.txt (or press Enter to skip)"
        if (-not [string]::IsNullOrWhiteSpace($cookiePath)) {
            Ins-SetCookie $cookiePath
            Write-Host "Path saved! Please run your Ins-Download command again.`n" -ForegroundColor Green
        }
    }

    Remove-Item $stdoutLog, $stderrLog -ErrorAction SilentlyContinue

    if ($proc.ExitCode -eq 0) { Write-Host "Done" } else { Write-Host "gallery-dl exited with code $($proc.ExitCode)" }
}

Set-Alias -Name ins_alias -Value Ins-Alias
Set-Alias -Name ins_download -Value Ins-Download
Set-Alias -Name ins_setdir -Value Ins-SetDir
Set-Alias -Name ins_setcookie -Value Ins-SetCookie

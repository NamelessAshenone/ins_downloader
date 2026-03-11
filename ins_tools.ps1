# PowerShell helpers for Instagram downloads (Windows)
# Mirrors macOS ins_alias / ins_download behavior

# Configurable defaults
$Global:InsAliasFile   = $env:INS_ALIAS_FILE   ? $env:INS_ALIAS_FILE   : "$env:USERPROFILE\.ins_aliases"
$Global:InsDownloadDir = $env:INS_DOWNLOAD_DIR ? $env:INS_DOWNLOAD_DIR : "$env:USERPROFILE\Pictures\ins_pictures"
$Global:InsChromeProfile = $env:INS_CHROME_PROFILE ? $env:INS_CHROME_PROFILE : "Default"

function Ins-Alias {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('add','modify','remove','delete','list','show','search','find')]
        [string]$Action,
        [string]$Alias,
        [string]$RealId
    )

    if (-not (Test-Path $Global:InsAliasFile)) { New-Item -ItemType File -Path $Global:InsAliasFile -Force | Out-Null }

    switch ($Action) {
        'add' { goto modify }
        'modify' {
            if ([string]::IsNullOrWhiteSpace($Alias) -or [string]::IsNullOrWhiteSpace($RealId)) { Write-Host "Usage: Ins-Alias add <alias> <real_username>"; return }
            # unique constraint: one real user -> one alias
            $lines = Get-Content $Global:InsAliasFile
            $existingAlias = $lines | Where-Object { $_ -match "^.+\s+$RealId$" } | ForEach-Object { ($_ -split '\s+')[0] }
            if ($existingAlias -and $existingAlias -ne $Alias) {
                $resp = Read-Host "User @$RealId already has alias [$existingAlias]. Overwrite with [$Alias]? (y/n)"
                if ($resp -notin @('y','Y')) { Write-Host "Cancelled."; return }
                $lines = $lines | Where-Object { $_ -notmatch "\s+$RealId$" }
            }
            $lines = $lines | Where-Object { $_ -notmatch "^$Alias\s+" }
            $lines += "$Alias $RealId"
            $lines | Set-Content $Global:InsAliasFile
            Write-Host "Saved: $Alias -> @$RealId"
        }
        'remove' { goto delete }
        'delete' {
            if ([string]::IsNullOrWhiteSpace($Alias)) { Write-Host "Usage: Ins-Alias delete <alias>"; return }
            (Get-Content $Global:InsAliasFile) | Where-Object { $_ -notmatch "^$Alias\s+" } | Set-Content $Global:InsAliasFile
            Write-Host "Deleted alias $Alias"
        }
        'list' { goto show }
        'show' {
            Write-Host "Aliases in $Global:InsAliasFile"
            Get-Content $Global:InsAliasFile | Sort-Object | ForEach-Object {
                if ($_ -match "^(\S+)\s+(\S+)$") { '{0,-15} {1}' -f $matches[1], $matches[2] }
            }
        }
        'search' { goto find }
        'find' {
            if ([string]::IsNullOrWhiteSpace($Alias)) { Write-Host "Usage: Ins-Alias search <keyword>"; return }
            Write-Host "Searching: $Alias"
            Get-Content $Global:InsAliasFile | Select-String -Pattern $Alias -SimpleMatch | ForEach-Object {
                if ($_.Line -match "^(\S+)\s+(\S+)$") { '{0,-15} {1}' -f $matches[1], $matches[2] }
            }
        }
    }
}

function Ins-Download {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)][string]$Input,
        [Parameter(Position=1)][string]$Directory,
        [int]$Top,
        [Nullable[int]]$Limit,
        [switch]$Only,
        [string]$Include,
        [string]$Exclude,
        [switch]$Help
    )

    if ($Help -or [string]::IsNullOrWhiteSpace($Input)) {
        Write-Host "Usage: Ins-Download <URL|alias|username> [-Top N] [-Limit [N]] [-Only] [-Include spec] [-Exclude spec]"
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

    $mode = ($Input -like 'http*') ? 'url' : 'user'
    $realUser = ''
    $currentAlias = ''

    if ($mode -eq 'url') {
        $cleanUrl = $Input -replace "\?.*", ''
        $Input = $cleanUrl
    } else {
        if ($aliasMap.ContainsKey($Input)) {
            $currentAlias = $Input
            $realUser = $aliasMap[$Input]
        } else {
            $realUser = $Input
        }
        $Input = "https://www.instagram.com/$realUser/"
    }

    $targetDir = if ($Directory) { $Directory } elseif ($currentAlias) { Join-Path $Global:InsDownloadDir $currentAlias } else { Join-Path $Global:InsDownloadDir ($realUser ? $realUser : 'unknown') }
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
            if ($Input -match 'img_index=([0-9]+)') { $gdlArgs += @('--range', $matches[1]) } else { $gdlArgs += @('--range', '1') }
        }
        if ($Top) { $gdlArgs += @('--range', "1-$Top") }
        if ($Include) { $gdlArgs += @('--range', $Include) }
        if ($Exclude) {
            if ($Exclude -match '([0-9]+)-([0-9]+)') { $gdlArgs += @('--filter', "num < $($matches[1]) or num > $($matches[2])") }
            else { $gdlArgs += @('--filter', "num != $Exclude") }
        }
        if ($PSBoundParameters.ContainsKey('Limit')) {
            $effective = ($Limit -gt 0) ? $Limit : 5
            $gdlArgs += @('--filter', "num <= $effective")
        }
    } else {
        $effectiveLimit = if ($PSBoundParameters.ContainsKey('Limit')) { ($Limit -gt 0) ? $Limit : 20 } else { 20 }
        if ($Top) { $gdlArgs += @('--range', "1-$Top") }
        $gdlArgs += @('--filter', "num <= $effectiveLimit")
    }

    $logFile = [System.IO.Path]::GetTempFileName()
    Write-Host "Downloading to $targetDir"
    $proc = Start-Process -FilePath "gallery-dl" -ArgumentList ($gdlArgs + @($Input)) -RedirectStandardOutput $logFile -RedirectStandardError $logFile -NoNewWindow -PassThru
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

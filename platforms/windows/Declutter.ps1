<#
.SYNOPSIS
    TWDxOSOptimisation - Windows disk cleanup / optimization script.

.DESCRIPTION
    Reports (and optionally clears) temp files, the Windows Update download
    cache, and old Windows.old / component-store leftovers. Default mode is
    REPORT ONLY - nothing is deleted unless -Apply is passed.

.PARAMETER Apply
    Actually perform the cleanup steps. Default: report only.

.PARAMETER DryRun
    Alias for the default (no -Apply) behavior; accepted for symmetry with
    the other platforms' scripts and CI tooling that always passes it.

.EXAMPLE
    .\Declutter.ps1
.EXAMPLE
    .\Declutter.ps1 -Apply

.NOTES
    Tested: Windows Server 2022, Windows 11 - x64 + arm64
    License: MIT
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$LogDir = "$env:ProgramData\TWDxOSOptimisation\Logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir "declutter-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'o')  $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

$ApplyChanges = $Apply -and -not $DryRun
Write-Log "Log file: $LogFile"
Write-Log "Mode: $(if ($ApplyChanges) { 'APPLY' } else { 'DRY-RUN report only' })"

$actionsTaken = 0

# ---------------------------------------------------------------------------
# 1. Temp files (user + system)
# ---------------------------------------------------------------------------
Write-Log "`n--- Temp files ---"
$tempPaths = @($env:TEMP, "$env:WINDIR\Temp")
foreach ($path in $tempPaths) {
    if (-not (Test-Path $path)) { continue }
    $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-10) }
    $sizeMB = [math]::Round((($items | Measure-Object -Property Length -Sum).Sum / 1MB), 1)
    Write-Log "$path : $($items.Count) items older than 10 days (~$sizeMB MB)"

    if ($ApplyChanges) {
        $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "[ACTION] Cleared $($items.Count) stale items from $path"
        $actionsTaken++
    } else {
        Write-Log "(dry-run) would remove $($items.Count) items from $path"
    }
}

# ---------------------------------------------------------------------------
# 2. Windows Update download cache
# ---------------------------------------------------------------------------
Write-Log "`n--- Windows Update cache ---"
$wuCache = "$env:WINDIR\SoftwareDistribution\Download"
if (Test-Path $wuCache) {
    $cacheSizeMB = [math]::Round(((Get-ChildItem -Path $wuCache -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum / 1MB), 1)
    Write-Log "Windows Update cache size: ~$cacheSizeMB MB"

    if ($ApplyChanges) {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $wuCache -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Write-Log "[ACTION] Cleared Windows Update download cache (~$cacheSizeMB MB)"
        $actionsTaken++
    } else {
        Write-Log "(dry-run) would stop wuauserv, clear $wuCache, restart wuauserv"
    }
}

# ---------------------------------------------------------------------------
# 3. Component store cleanup (DISM) + old Windows.old
# ---------------------------------------------------------------------------
Write-Log "`n--- Component store / Windows.old ---"
if (Test-Path "$env:SystemDrive\Windows.old") {
    Write-Log "Windows.old present (leftover from a previous Windows upgrade)."
    if ($ApplyChanges) {
        if ($PSCmdlet.ShouldProcess("$env:SystemDrive\Windows.old", "Remove via Disk Cleanup (cleanmgr)")) {
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -ErrorAction SilentlyContinue
            Write-Log "[ACTION] Ran Disk Cleanup (cleanmgr /sagerun:1) to remove Windows.old"
            $actionsTaken++
        }
    } else {
        Write-Log "(dry-run) would run: cleanmgr /sagerun:1 (removes Windows.old, requires /sageset:1 configured once)"
    }
} else {
    Write-Log "No Windows.old found."
}

if ($ApplyChanges) {
    try {
        Dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet | Out-Null
        Write-Log "[ACTION] DISM component store cleanup completed"
        $actionsTaken++
    } catch {
        Write-Log "DISM cleanup failed: $($_.Exception.Message)"
    }
} else {
    Write-Log "(dry-run) would run: Dism.exe /Online /Cleanup-Image /StartComponentCleanup"
}

# ---------------------------------------------------------------------------
# 4. Reboot-pending check (companion to the Linux platforms' auto-reboot)
# ---------------------------------------------------------------------------
Write-Log "`n--- Reboot-pending check ---"
$rebootPending = $false
$rebootKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
)
foreach ($key in $rebootKeys) {
    if (Test-Path $key) { $rebootPending = $true }
}
if ($rebootPending) {
    Write-Log "*** REBOOT REQUIRED - a pending update needs a restart to complete ***"
} else {
    Write-Log "No reboot currently required."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Log "`n--- Summary ---"
Write-Log "Mode used: $(if ($ApplyChanges) { 'APPLY' } else { 'DRY-RUN' })"
Write-Log "Actions taken: $actionsTaken"
Write-Log "Full details written to: $LogFile"

if (-not $ApplyChanges) {
    Write-Log "Re-run with -Apply to actually perform these steps."
}

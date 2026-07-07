<#
.SYNOPSIS
    TWDxOSOptimisation - Windows Uninstaller

.DESCRIPTION
    Removes the scheduled Declutter.ps1 task, the installed copy of
    Declutter.ps1, and the TWDxOSOptimisation-SSH firewall rule (if
    present). Optionally reverts the Defender Firewall default-inbound
    policy and restores the original sshd_config backup.

.EXAMPLE
    .\Uninstall.ps1

.NOTES
    License: MIT
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-Info    { param([string]$Message) Write-Host "[info]  $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "[ ok ]  $Message" -ForegroundColor Green }
function Write-Warn    { param([string]$Message) Write-Host "[warn]  $Message" -ForegroundColor Yellow }
function Write-ErrorX  { param([string]$Message) Write-Host "[fail]  $Message" -ForegroundColor Red; exit 1 }

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-ErrorX "Please run this script from an elevated (Administrator) PowerShell session."
}

Write-Host ""
Write-Host "  =================================================================" -ForegroundColor Cyan
Write-Host "              TWDxOSOptimisation - Windows Uninstaller              " -ForegroundColor Cyan
Write-Host "  =================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Warn "This will remove all TWDxOSOptimisation (Windows) components."
$confirm = Read-Host "  Continue? [y/N]"
if ($confirm -notmatch '^[Yy]$') {
    Write-Info "Aborted."
    exit 0
}

# Scheduled task
$TaskName = "TWDxOSOptimisation-Declutter"
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Success "Removed scheduled task '$TaskName'"
}

# Installed files
$InstallDir = "C:\Program Files\TWDxOSOptimisation"
if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Success "Removed $InstallDir"
}

# SSH firewall rule (harden.ps1)
if (Get-NetFirewallRule -DisplayName "TWDxOSOptimisation-SSH" -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -DisplayName "TWDxOSOptimisation-SSH"
    Write-Success "Removed TWDxOSOptimisation-SSH firewall rule"
}

# sshd_config restore (harden.ps1) - optional
$sshdConfigPath = "$env:ProgramData\ssh\sshd_config"
$backupPath = "$sshdConfigPath.twdxos-backup"
if (Test-Path $backupPath) {
    $restore = Read-Host "  Restore original sshd_config from backup? [y/N]"
    if ($restore -match '^[Yy]$') {
        Copy-Item -Path $backupPath -Destination $sshdConfigPath -Force
        Restart-Service sshd -ErrorAction SilentlyContinue
        Write-Success "sshd_config restored from backup"
    }
}

# Firewall default-inbound policy (harden.ps1/install.ps1) - optional
$revertFw = Read-Host "  Revert Defender Firewall to default-allow inbound (undo hardening)? [y/N]"
if ($revertFw -match '^[Yy]$') {
    Set-NetFirewallProfile -All -DefaultInboundAction Allow
    Write-Success "Firewall default inbound action reverted to Allow"
}

Write-Host ""
Write-Host "  TWDxOSOptimisation (Windows) has been removed." -ForegroundColor Green
Write-Host "  Logs remain at `$env:ProgramData\TWDxOSOptimisation\Logs. Remove them manually if no longer needed."
Write-Host ""

<#
.SYNOPSIS
    TWDxOSOptimisation - Windows Server/Desktop hardening.

.DESCRIPTION
    Hardens Windows Defender Firewall (default-deny inbound, logging),
    enforces Network Level Authentication for RDP, and - if the optional
    OpenSSH Server feature is installed - hardens sshd_config. Windows'
    OpenSSH port ships a single sshd_config file (no sshd_config.d Include
    mechanism like the Linux/macOS platforms), so this script backs up the
    file once before editing it rather than using a drop-in.

.PARAMETER DryRun
    Preview every change without applying it.

.PARAMETER EnableRdpHardening
    Enforce NLA for Remote Desktop. Default: $true

.PARAMETER SshPort
    Port to allow through the firewall for OpenSSH Server, if installed.
    Default: 22

.EXAMPLE
    .\Harden.ps1 -DryRun

.NOTES
    Tested: Windows Server 2022, Windows 11 - x64 + arm64
    License: MIT
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [bool]$EnableRdpHardening = $true,
    [int]$SshPort = 22
)

$ErrorActionPreference = "Stop"

function Write-Info    { param([string]$Message) Write-Host "[info]  $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "[ ok ]  $Message" -ForegroundColor Green }
function Write-Warn    { param([string]$Message) Write-Host "[warn]  $Message" -ForegroundColor Yellow }
function Write-ErrorX  { param([string]$Message) Write-Host "[fail]  $Message" -ForegroundColor Red; exit 1 }
function Write-Step    { param([string]$Message) Write-Host "`n>> $Message" -ForegroundColor White }
function Write-DryRun  { param([string]$Message) Write-Host "[dry-run]  Would: $Message" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  =================================================================" -ForegroundColor Cyan
Write-Host "          TWDxOSOptimisation - Windows Hardening                    " -ForegroundColor Cyan
Write-Host "                                                                   " -ForegroundColor Cyan
Write-Host "               Developed by: TheWebDexter.com                      " -ForegroundColor Cyan
Write-Host "  =================================================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) { Write-Warn "Dry-run mode: no changes will be made." }

Write-Step "Preflight Checks"
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-ErrorX "Please run this script from an elevated (Administrator) PowerShell session."
}
if ($SshPort -lt 1 -or $SshPort -gt 65535) {
    Write-ErrorX "SshPort must be between 1 and 65535 (got: $SshPort)"
}

# ---------------------------------------------------------------------------
# 1. Windows Defender Firewall
# ---------------------------------------------------------------------------
Write-Step "Windows Defender Firewall hardening"
if ($DryRun) {
    Write-DryRun "Set-NetFirewallProfile -All -DefaultInboundAction Block -LogBlocked True"
    Write-DryRun "Set-NetFirewallProfile -All -LogMaxSizeKilobytes 16384"
} else {
    Set-NetFirewallProfile -All -DefaultInboundAction Block -DefaultOutboundAction Allow -Enabled True
    Set-NetFirewallProfile -All -LogBlocked True -LogMaxSizeKilobytes 16384
    Write-Success "Firewall hardened (default deny inbound, dropped-packet logging on)"
}

# ---------------------------------------------------------------------------
# 2. RDP - Network Level Authentication
# ---------------------------------------------------------------------------
if ($EnableRdpHardening) {
    Write-Step "RDP Network Level Authentication"
    $rdpTsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
    if ($DryRun) {
        Write-DryRun "Set-ItemProperty '$rdpTsKey' -Name UserAuthentication -Value 1"
    } else {
        if (Test-Path $rdpTsKey) {
            Set-ItemProperty -Path $rdpTsKey -Name "UserAuthentication" -Value 1 -Type DWord
            Write-Success "RDP NLA enforced (UserAuthentication=1)"
        } else {
            Write-Warn "RDP registry key not found - Remote Desktop may not be installed/enabled. Skipping."
        }
    }
}

# ---------------------------------------------------------------------------
# 3. OpenSSH Server hardening (optional Windows feature)
# ---------------------------------------------------------------------------
Write-Step "OpenSSH Server hardening (if installed)"
$sshdConfigPath = "$env:ProgramData\ssh\sshd_config"
$sshFeature = Get-WindowsCapability -Online -Name "OpenSSH.Server*" -ErrorAction SilentlyContinue |
    Where-Object { $_.State -eq "Installed" }

if (-not $sshFeature -or -not (Test-Path $sshdConfigPath)) {
    Write-Info "OpenSSH Server is not installed - skipping (this is the common case on Windows)."
} else {
    if ($DryRun) {
        Write-DryRun "Back up $sshdConfigPath -> $sshdConfigPath.twdxos-backup (once)"
        Write-DryRun "Apply PermitRootLogin no / PasswordAuthentication no / MaxAuthTries 3 (if not already set)"
        Write-DryRun "New-NetFirewallRule for port $SshPort, restart sshd"
    } else {
        # Windows' OpenSSH ships one sshd_config with no Include mechanism for a
        # drop-in directory (unlike the Linux/macOS platforms) - back it up once
        # before mutating it directly, rather than silently editing repeatedly.
        $backupPath = "$sshdConfigPath.twdxos-backup"
        if (-not (Test-Path $backupPath)) {
            Copy-Item -Path $sshdConfigPath -Destination $backupPath
            Write-Info "Backed up original sshd_config to $backupPath"
        }

        $desired = @{
            "PermitRootLogin"        = "no"
            "PasswordAuthentication" = "no"
            "MaxAuthTries"           = "3"
        }
        $content = Get-Content $sshdConfigPath
        foreach ($setting in $desired.GetEnumerator()) {
            $pattern = "^\s*#?\s*$($setting.Key)\s+.*$"
            $replacement = "$($setting.Key) $($setting.Value)"
            if ($content -match $pattern) {
                $content = $content -replace $pattern, $replacement
            } else {
                $content += $replacement
            }
        }
        Set-Content -Path $sshdConfigPath -Value $content

        New-NetFirewallRule -DisplayName "TWDxOSOptimisation-SSH" -Direction Inbound `
            -Protocol TCP -LocalPort $SshPort -Action Allow -ErrorAction SilentlyContinue | Out-Null

        Restart-Service sshd -ErrorAction SilentlyContinue
        Write-Success "OpenSSH Server hardened (backup at $backupPath)"
    }
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "----------------------------------------------------" -ForegroundColor White
if ($DryRun) {
    Write-Host "  Dry-run complete - no changes were made." -ForegroundColor Yellow
} else {
    Write-Host "  Hardening complete on $env:COMPUTERNAME" -ForegroundColor Green
}
Write-Host "----------------------------------------------------" -ForegroundColor White
Write-Host ""
Write-Host "  Thank you for using automation by TheWebDexter.com" -ForegroundColor Cyan
Write-Host ""

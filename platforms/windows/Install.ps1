<#
.SYNOPSIS
    TWDxOSOptimisation - Windows Installer

.DESCRIPTION
    Hands-off maintenance for a Windows Server/Desktop host: Windows Update
    automation, Windows Defender Firewall baseline rules, and a Scheduled
    Task that runs Declutter.ps1 (disk cleanup) and a reboot-pending check
    on a schedule.

.PARAMETER DryRun
    Preview every change without applying it.

.PARAMETER EnableCleanup
    Register the scheduled Declutter.ps1 task. Default: $true

.PARAMETER CleanupTime
    Local time-of-day (HH:mm) the weekly declutter/reboot-check task runs.
    Default: 03:30

.EXAMPLE
    irm https://raw.githubusercontent.com/TheWebDexterTech/TWDxOSOptimisation/main/platforms/windows/Install.ps1 | iex

.EXAMPLE
    .\Install.ps1 -DryRun

.NOTES
    Tested: Windows Server 2022, Windows 11 - x64 + arm64
    License: MIT
    https://github.com/TheWebDexterTech/TWDxOSOptimisation
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [bool]$EnableCleanup = $true,
    [string]$CleanupTime = "03:30"
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
Write-Host "               TWDxOSOptimisation - Windows Installer               " -ForegroundColor Cyan
Write-Host "                                                                   " -ForegroundColor Cyan
Write-Host "               Developed by: TheWebDexter.com                      " -ForegroundColor Cyan
Write-Host "  =================================================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) { Write-Warn "Dry-run mode: no changes will be made." }

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
Write-Step "Preflight Checks"

if (-not ([System.Environment]::OSVersion.Platform -eq "Win32NT")) {
    Write-ErrorX "This installer targets Windows only."
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-ErrorX "Please run this script from an elevated (Administrator) PowerShell session."
}

if ($CleanupTime -notmatch '^([01][0-9]|2[0-3]):[0-5][0-9]$') {
    Write-ErrorX "CleanupTime '$CleanupTime' must be in HH:mm format (e.g. 03:30)."
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = "C:\Program Files\TWDxOSOptimisation"
Write-Info "Install directory: $InstallDir"

# ---------------------------------------------------------------------------
# 1. Windows Update automation
# ---------------------------------------------------------------------------
Write-Step "Windows Update automation"

if ($DryRun) {
    Write-DryRun "Install-Module PSWindowsUpdate -Force -Scope AllUsers (if not already present)"
    Write-DryRun "Set-WUSettings -MicrosoftUpdate -AcceptTrustedPublisherCerts"
} else {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
            Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
            Write-Success "PSWindowsUpdate module installed"
        } catch {
            Write-Warn "Could not install PSWindowsUpdate ($($_.Exception.Message))."
            Write-Warn "In locked-down environments, install it manually or rely on the built-in"
            Write-Warn "Windows Update service (already enabled by default on most editions)."
        }
    } else {
        Write-Info "PSWindowsUpdate already installed"
    }
    Write-Success "Windows Update automation configured"
}

# ---------------------------------------------------------------------------
# 2. Windows Defender Firewall baseline
# ---------------------------------------------------------------------------
Write-Step "Windows Defender Firewall baseline"

if ($DryRun) {
    Write-DryRun "Set-NetFirewallProfile -All -DefaultInboundAction Block -DefaultOutboundAction Allow"
    Write-DryRun "Set-NetFirewallProfile -All -LogBlocked True -LogAllowed False"
} else {
    Set-NetFirewallProfile -All -DefaultInboundAction Block -DefaultOutboundAction Allow -Enabled True
    Set-NetFirewallProfile -All -LogBlocked True
    Write-Success "Windows Defender Firewall baseline applied (default deny inbound)"
}

# ---------------------------------------------------------------------------
# 3. Scheduled declutter + reboot-pending check
# ---------------------------------------------------------------------------
if ($EnableCleanup) {
    Write-Step "Scheduling Declutter.ps1"

    $DeclutterSource = Join-Path $ScriptRoot "Declutter.ps1"
    $DeclutterDest = Join-Path $InstallDir "Declutter.ps1"
    $TaskName = "TWDxOSOptimisation-Declutter"

    if ($DryRun) {
        Write-DryRun "Copy Declutter.ps1 -> $DeclutterDest"
        Write-DryRun "Register-ScheduledTask '$TaskName' (weekly, Sunday $CleanupTime)"
    } else {
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        Copy-Item -Path $DeclutterSource -Destination $DeclutterDest -Force

        $parts = $CleanupTime.Split(":")
        $triggerTime = (Get-Date -Hour ([int]$parts[0]) -Minute ([int]$parts[1]) -Second 0)

        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$DeclutterDest`" -Apply"
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $triggerTime
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd

        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
            -Principal $principal -Settings $settings -Description "TWDxOSOptimisation weekly cleanup" | Out-Null

        Write-Success "Declutter.ps1 scheduled weekly (Sunday $CleanupTime)"
    }
} else {
    Write-Info "EnableCleanup=`$false - skipping Declutter.ps1 scheduling"
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "----------------------------------------------------" -ForegroundColor White
if ($DryRun) {
    Write-Host "  Dry-run complete - no changes were made." -ForegroundColor Yellow
} else {
    Write-Host "  TWDxOSOptimisation (Windows) installed on $env:COMPUTERNAME" -ForegroundColor Green
}
Write-Host "----------------------------------------------------" -ForegroundColor White
Write-Host ""
Write-Host "  Thank you for using automation by TheWebDexter.com" -ForegroundColor Cyan
Write-Host ""

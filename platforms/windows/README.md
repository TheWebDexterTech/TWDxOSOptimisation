# TWDxOSOptimisation — Windows

Hands-off maintenance for a Windows Server or Desktop host: Windows Update automation, a Windows Defender Firewall baseline, a scheduled disk-cleanup/reboot-check job, and optional RDP/OpenSSH hardening.

This folder is self-contained — it has no dependency on any other platform folder in this repo, and no WP-CLI module (see `Modules/README.md` for why).

**Developed by [TheWebDexter.com](https://thewebdexter.com)**

---

## What it does

| Layer | Tool | When |
|---|---|---|
| OS updates | `PSWindowsUpdate` module (falls back to built-in Windows Update service if the module can't install) | Managed by Windows Update itself once configured |
| Firewall baseline | Windows Defender Firewall — default-deny inbound, dropped-packet logging | Applied once by `Install.ps1`/`Harden.ps1` |
| Disk cleanup / reboot-pending check | `Declutter.ps1` via Scheduled Task | Weekly (default Sunday 03:30 local time) |
| RDP hardening | Enforces Network Level Authentication | Applied once by `Harden.ps1` |
| OpenSSH Server hardening (if installed) | Direct `sshd_config` edit (backed up once first) | Applied once by `Harden.ps1` |

## Requirements

- Windows Server 2022 or Windows 11 (x64 or arm64)
- An elevated (Administrator) PowerShell session
- PowerShell 5.1+ (ships with Windows) or PowerShell 7+

## Quick Install

```powershell
irm https://raw.githubusercontent.com/TheWebDexterTech/TWDxOSOptimisation/main/platforms/windows/Install.ps1 | iex
```

Or, from a clone:

```powershell
git clone https://github.com/TheWebDexterTech/TWDxOSOptimisation.git
cd TWDxOSOptimisation\platforms\windows
.\Install.ps1
```

## Dry-Run Mode

```powershell
.\Install.ps1 -DryRun
```

## Hardening (optional)

```powershell
.\Harden.ps1 [-DryRun]
```

| Parameter | Default | Description |
|---|---|---|
| `-EnableRdpHardening` | `$true` | Enforce NLA for Remote Desktop |
| `-SshPort` | `22` | Firewall port opened for OpenSSH Server, if installed |
| `-DryRun` | off | Preview without applying |

> **Note on OpenSSH:** unlike the Linux/macOS platforms, Windows' OpenSSH Server ships a single `sshd_config` with no `Include`-a-directory mechanism — `Harden.ps1` backs the file up once (`sshd_config.twdxos-backup`) before editing it directly, rather than using a drop-in.

## Declutter script

```powershell
.\Declutter.ps1            # report only
.\Declutter.ps1 -Apply     # clear stale temp files, WU cache, run DISM component cleanup
```

Logs to `$env:ProgramData\TWDxOSOptimisation\Logs\`.

## Scheduled Task

`Install.ps1` registers a Scheduled Task (`TWDxOSOptimisation-Declutter`) that runs `Declutter.ps1 -Apply` weekly, running as `SYSTEM`. `Configs\ScheduledTask-Declutter.xml.tpl` documents the same trigger shape for reference / manual `schtasks /create /xml` use — `Install.ps1` itself builds the task via `Register-ScheduledTask`, it does not import this XML file.

## Optional WordPress module

There isn't one on this platform — see [`Modules/README.md`](Modules/README.md) for why, and what to do instead if you need WP-CLI automation on Windows/IIS.

## Uninstall

```powershell
.\Uninstall.ps1
```

## License

MIT

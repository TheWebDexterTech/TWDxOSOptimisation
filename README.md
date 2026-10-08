# TWDxOSOptimisation

A hands-off OS optimization, hardening, and maintenance toolkit — one self-contained folder per platform, each independently maintained.

**Developed by [TheWebDexter.com](https://thewebdexter.com)**

---

## Why one folder per platform?

This project deliberately does **not** try to unify Linux, macOS, and Windows behind a shared abstraction or a single dispatcher script. Each platform folder under `platforms/` is self-contained: its own installer, its own hardening script, its own cleanup script, its own docs. A contributor who only cares about one OS can open that one folder, read it end-to-end, and edit it without needing to understand (or touch) any of the others. Some duplication across folders is the deliberate tradeoff for that independence.

## Platforms

| Platform | Docs |
|---|---|
| Linux — Debian / Ubuntu | [platforms/linux-debian/README.md](platforms/linux-debian/README.md) |
| Linux — RHEL / Fedora / CentOS | [platforms/linux-rhel/README.md](platforms/linux-rhel/README.md) |
| macOS | [platforms/macos/README.md](platforms/macos/README.md) |
| Windows | [platforms/windows/README.md](platforms/windows/README.md) |

Each does some combination of: unattended OS **security** updates, intrusion prevention / firewall hardening, SSH hardening, kernel/network sysctl hardening, time-sync assurance, journald/log retention, scheduled disk/log/cache cleanup, and a conditional reboot when a pending update requires one — using whatever native tooling that platform actually has (apt/unattended-upgrades + fail2ban + UFW on Debian, dnf-automatic + firewalld on RHEL, launchd + Homebrew on macOS, Task Scheduler + Windows Defender Firewall + telemetry/LLMNR/SMBv1/Defender hardening on Windows).

### Enterprise CLI contract (v2.0.0)

| Flag | Bash `install` | Bash `harden` | Bash `uninstall` | Bash `declutter` | Windows (all scripts) |
|---|---|---|---|---|---|
| `--dry-run` / `--check` | ✓ | ✓ | ✓ | report-only unless `--apply` | `-DryRun` |
| `--json` — single-line JSON result on stdout, logs on stderr | ✓ | ✓ | ✓ | ✓ | `-Json` |
| `--non-interactive` — never prompt, fail closed | ✓ | ✓ | ✓ | `--cron` | `-NonInteractive` (not Declutter) |
| `--offline` — use files beside the script (`BUNDLE_DIR`) | ✓ | | | | |
| `--require-signatures` — minisign check is mandatory | ✓ | | | | |
| `--strict` — non-interactive (+ signatures for install) | ✓ | ✓ | | | |
| `--ref <tag\|sha>` — fetch configs from a pinned ref | ✓ | | | | |

Stable exit codes: **0** ok · **2** usage · **3** preflight · **4** partial · **5** integrity (Bash `install` only).

The full v2.0.0 behaviour-change list is in [the v2.0.0 PR](https://github.com/TheWebDexterTech/TWDxOSOptimisation/pull/12) and the project's TWDxMCP changelog node; the short version: Linux updates are now security-only, needrestart lists instead of restarting, fail2ban whitelists loopback only, and `harden` fails closed when it could lock you out.

## Optional WordPress module

This project originally shipped as a WordPress-server-specific toolkit (formerly `TWDxWordPressServerSecurity`, focused on Ubuntu). WP-CLI auto-update is still available as an **optional add-on module** inside the Linux and macOS platform folders (`modules/wp-auto-update.sh.tpl`) — it is not the centerpiece of the project. There is no WP-CLI module on Windows; see [`platforms/windows/Modules/README.md`](platforms/windows/Modules/README.md) for why.

## Contributing

Pick the platform folder you care about and read its own `README.md`. Architecture, per-file code maps, conventions and the changelog live in the **TWDxMCP** memory server (TheWebDexter's project knowledge base), not in repo docs — `CLAUDE.md` lists the project, workspace and node IDs to load.

The commit preflight runs learned checks, ShellCheck across every Bash platform, checksum-drift detection and a staged-diff secret scan. Enable it once per clone:

```bash
git config core.hooksPath .husky
bash .claude/scripts/preflight.sh   # full manual run (adds PSScriptAnalyzer when pwsh is installed)
```

## License

MIT — see [LICENSE](LICENSE).

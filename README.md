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

Each does some combination of: unattended OS security updates, intrusion prevention / firewall hardening, SSH hardening, kernel/network sysctl hardening, scheduled disk/log/cache cleanup, and a conditional reboot when a pending update requires one — using whatever native tooling that platform actually has (apt/unattended-upgrades + fail2ban + UFW on Debian, dnf-automatic + firewalld on RHEL, launchd + Homebrew on macOS, Task Scheduler + Windows Defender Firewall on Windows).

## Optional WordPress module

This project originally shipped as a WordPress-server-specific toolkit (formerly `TWDxWordPressServerSecurity`, focused on Ubuntu). WP-CLI auto-update is still available as an **optional add-on module** inside the Linux and macOS platform folders (`modules/wp-auto-update.sh.tpl`) — it is not the centerpiece of the project. There is no WP-CLI module on Windows; see [`platforms/windows/Modules/README.md`](platforms/windows/Modules/README.md) for why.

## Contributing

Pick the platform folder you care about and read its own `README.md`/`CLAUDE.md`. All shell scripts across the Linux/macOS platforms share a few conventions worth knowing (dry-run mode, drop-in configs, a `FILE_CHECKSUMS` registry for anything fetched over the network) — see any platform's `CLAUDE.md` for the details, or the root `CLAUDE.md` for the project-wide philosophy.

`scripts/pre-commit.sh` is a repo-wide commit preflight (ShellCheck across every Bash platform, checksum-drift detection, a staged-diff secret scan) — install it once per clone:

```bash
ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
chmod +x scripts/pre-commit.sh
```

## License

MIT — see [LICENSE](LICENSE).

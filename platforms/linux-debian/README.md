# TWDxOSOptimisation — Linux (Debian/Ubuntu)

Hands-off maintenance for headless servers on Ubuntu 24.04 (and Debian-family distros generally). Set it up once and forget about it — security patches, bug fixes, service restarts, kernel reboots, system cleanup, log rotation, intrusion prevention, and (optionally) WordPress updates all happen automatically.

This is the original project (formerly `TWDxWordPressServerSecurity`), now living as one self-contained folder inside a larger multi-platform project. It has no dependency on any other platform folder in this repo.

**Developed by [TheWebDexter.com](https://thewebdexter.com)**

---

## What it does

| Layer | Tool | When |
|---|---|---|
| OS security patches + bug fixes | `unattended-upgrades` | Daily |
| Intrusion Prevention (SSH brute-force + repeat-offender ban) | `fail2ban` (tuned jail) | Always Active |
| Restart services after library updates | `needrestart` | After every `apt` run |
| Reboot if a kernel update is pending | systemd timer | Nightly (default 03:30 UTC) |
| System Cleanup (apt caches & logs) | bash + cron | Configurable (Default: Weekly) |
| Log Rotation (compress & clean old logs) | `logrotate` | Weekly |
| Update WP core, plugins, themes, and DB Optimize (optional module) | WP-CLI + cron (with `flock` lock) | Configurable (Default: Weekly) |

---

## Requirements

- Ubuntu 24.04 LTS (tested on both `x86_64` and `aarch64`)
- Root or sudo access
- Outbound internet access (to fetch configs on first run; WP-CLI too, if the optional module is used)

---

## Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/TheWebDexterTech/TWDxOSOptimisation/main/platforms/linux-debian/install.sh | sudo bash
```

The script is entirely **idempotent** — safe to re-run on an existing server if you want to update your settings or get the latest features.

> **Security note:** Every config file and script downloaded during install is verified against a hardcoded SHA256 digest before being written to disk. WP-CLI is verified against its official SHA512 hash. If any file has been tampered with in transit, the installer aborts.

## Manual Install (Clone Repository)

```bash
git clone https://github.com/TheWebDexterTech/TWDxOSOptimisation.git
cd TWDxOSOptimisation/platforms/linux-debian
sudo bash install.sh
```

## Dry-Run Mode

```bash
sudo bash install.sh --dry-run
# or
sudo DRY_RUN=true bash install.sh
```

---

## Server Hardening (Optional)

```bash
sudo bash harden.sh [--dry-run]
```

| Layer | What it does |
|---|---|
| SSH daemon | Writes a drop-in at `/etc/ssh/sshd_config.d/99-twdxos-hardening.conf` so the main `sshd_config` is left untouched. CIS-aligned: disables root login, passwords, agent/TCP/X11 forwarding, sets `MaxAuthTries 3`, `LoginGraceTime 30`, `ClientAliveInterval 300`, and pins Mozilla "modern" KEX/Ciphers/MACs/HostKeyAlgorithms. Validates with `sshd -t` before reload. |
| Kernel & network stack | Writes `/etc/sysctl.d/99-twdxos-hardening.conf`: TCP SYN cookies, rp_filter, no redirects / source routing (v4 **and** v6), martian logging, `kptr_restrict=2`, `dmesg_restrict=1`, `yama.ptrace_scope=2`, `kexec_load_disabled=1`, `unprivileged_bpf_disabled=1`, BPF JIT hardening, and the full `fs.protected_*` family. |
| UFW firewall | Installs and enables UFW (IPv6 explicit, low logging) with `deny incoming` / `allow outgoing` defaults, and opens your SSH port (22), HTTP (80), and HTTPS (443). |

**Headless example:**

```bash
sudo SSH_PORT=22 OPEN_HTTP=true OPEN_HTTPS=true bash harden.sh
```

| Variable | Default | Description |
|---|---|---|
| `SSH_PORT` | `22` | Port UFW will keep open for SSH |
| `ENABLE_UFW` | `true` | Install and enable UFW |
| `OPEN_HTTP` | `true` | Allow port 80 (required for Let's Encrypt / Cloudflare) |
| `OPEN_HTTPS` | `true` | Allow port 443 |
| `DRY_RUN` | `false` | Preview all changes without applying |

> **Safety check:** The script detects whether any non-root user has an `authorized_keys` file before disabling password authentication. If none is found, it warns and prompts before continuing — preventing accidental lockout.

### Raising the Drawbridge (Cloudflare Tunnel)

For maximum security, route SSH through a Cloudflare Zero Trust tunnel so the server has zero open inbound ports. Once the tunnel is confirmed working, remove the SSH rule:

```bash
sudo ufw delete allow 22/tcp && sudo ufw reload
```

Also delete the SSH ingress rule from your cloud provider's VCN / Security Group (e.g. Oracle Cloud Dashboard).

### Ubuntu Pro (Extended Security Maintenance)

```bash
sudo pro attach YOUR_TOKEN_HERE
```

Optional — `unattended-upgrades` already covers the base Ubuntu packages without it.

---

## Headless Configuration (install.sh)

```bash
curl -fsSL https://raw.githubusercontent.com/TheWebDexterTech/TWDxOSOptimisation/main/platforms/linux-debian/install.sh | \
  sudo WP_PATH=/var/www/mysite \
  WP_USER=nginx \
  ENABLE_CLEANUP=true \
  CRON_SCHEDULE="0 4 * * 1" \
  ADMIN_EMAIL=ops@yourcompany.com \
  bash
```

| Variable | Default | Description |
| --- | --- | --- |
| `WP_PATH` | `/var/www/html` | Absolute path to WordPress root (optional module) |
| `WP_USER` | `www-data` | OS user that owns WP files |
| `ENABLE_CLEANUP` | `true` | Automates `apt autoremove/autoclean` and journal log trimming |
| `CRON_SCHEDULE` | `0 3 * * 0` | Standard cron string for WP updates (Default: Sun 03:00) |
| `REBOOT_TIME` | `03:30:00` | Nightly reboot check time (UTC, format HH:MM:SS) |
| `LOG_FILE` | `/var/log/wp-auto-update.log` | WP update log path |
| `ADMIN_EMAIL` | *(empty)* | Email address for cron failure alerts (sets `MAILTO` in cron job) |
| `DRY_RUN` | `false` | Set to `true` to preview changes without applying them |

*(If `ENABLE_CLEANUP` is true, the cleanup script automatically runs 30 minutes after the WordPress update to prevent CPU spikes.)*

---

## Declutter script

```bash
sudo bash declutter.sh                       # report only
sudo bash declutter.sh --apply               # apt full-upgrade, autoremove, cache/log/tmp cleanup
sudo bash declutter.sh --apply --aggressive  # + interactive review of inactive services / unused packages
sudo bash declutter.sh --cron                # non-interactive, for scheduled runs
```

Logs to `/var/log/linux-declutter/`.

## Verify the install

```bash
systemctl status unattended-upgrades
systemctl status fail2ban
unattended-upgrade --dry-run
systemctl list-timers auto-reboot.timer
sudo -u www-data wp --path=/var/www/html core version   # if the WP-CLI module is enabled
cat /etc/cron.d/twdxos
```

## Logs

| What | Where |
| --- | --- |
| OS updates | `/var/log/unattended-upgrades/unattended-upgrades.log` |
| Intrusion blocks | `/var/log/fail2ban.log` (jail status: `sudo fail2ban-client status sshd`) |
| WP updates | `/var/log/wp-auto-update.log` |
| System Cleanup | `/var/log/vm-system-cleanup.log` |

Log files are created with mode `640` (root:adm) — not world-readable.

## Optional WordPress module

`modules/wp-auto-update.sh.tpl` is not the centerpiece of this platform. It's installed only via the WP-CLI section of `install.sh`, which no-ops safely (just a warning) if WordPress isn't found at `WP_PATH`.

## Notes

* **Reboots** only happen when a kernel update is actually pending (`/var/run/reboot-required`).
* **Reboots with active users** are disabled by default — see `/etc/apt/apt.conf.d/50unattended-upgrades` to adjust.
* **Cron jobs** are written to `/etc/cron.d/twdxos` rather than the root crontab.

## Uninstall

```bash
sudo bash uninstall.sh
```

## License

MIT

# TWDxWordPressServerSecurity

Hands-off maintenance for headless WordPress servers on Ubuntu 24.04. Set it up once and forget about it — security patches, bug fixes, service restarts, kernel reboots, system cleanup, log rotation, intrusion prevention, and WordPress updates all happen automatically.

Built for lean cloud setups where you want the server to take care of itself.

**Developed by [TheWebDexter.com](https://thewebdexter.com)**

---

## What it does

| Layer | Tool | When |
|---|---|---|
| OS security patches + bug fixes | `unattended-upgrades` | Daily |
| Intrusion Prevention (SSH brute-force protection) | `fail2ban` | Always Active |
| Restart services after library updates | `needrestart` | After every `apt` run |
| Reboot if a kernel update is pending | systemd timer | Nightly (default 03:30 UTC) |
| System Cleanup (apt caches & logs) | bash + cron | Configurable (Default: Weekly) |
| Log Rotation (compress & clean old logs) | `logrotate` | Weekly |
| Update WP core, plugins, themes, and DB Optimize | WP-CLI + cron | Configurable (Default: Weekly) |

---

## Requirements

- Ubuntu 24.04 LTS (tested on both `x86_64` and `aarch64`)
- Root or sudo access
- WordPress already installed
- Outbound internet access (to fetch WP-CLI and configs on first run)

---

## Quick Install (Recommended)

You do not need to clone this repository. Simply run the following one-liner on your server. It includes an interactive terminal menu to configure your maintenance schedule and cleanup preferences.

```bash
curl -fsSL https://raw.githubusercontent.com/thewebdexter/TWDxWordPressServerSecurity/main/install.sh | sudo bash
```

The script is entirely **idempotent** — it is completely safe to re-run on an existing server if you want to update your settings or get the latest features.

> **Security note:** Every config file and script downloaded during install is verified against a hardcoded SHA256 digest before being written to disk. WP-CLI is verified against its official SHA512 hash. If any file has been tampered with in transit, the installer aborts.

---

## Manual Install (Clone Repository)

If you prefer to review the files locally or make your own modifications before installing, you can clone the repository directly:

```bash
git clone https://github.com/thewebdexter/TWDxWordPressServerSecurity.git
cd TWDxWordPressServerSecurity
sudo bash install.sh
```

---

## Dry-Run Mode

Preview every change the installer would make — nothing is written to disk:

```bash
sudo bash install.sh --dry-run
# or
sudo DRY_RUN=true bash install.sh
```

---

## Headless Configuration (Optional)

If you prefer to bypass the interactive menu (e.g., for automated provisioning), you can pass all configuration options as inline environment variables. This works for both the quick install and the manual install:

**One-liner example:**

```bash
curl -fsSL https://raw.githubusercontent.com/thewebdexter/TWDxWordPressServerSecurity/main/install.sh | \
  sudo WP_PATH=/var/www/mysite \
  WP_USER=nginx \
  ENABLE_CLEANUP=true \
  CRON_SCHEDULE="0 4 * * 1" \
  ADMIN_EMAIL=ops@yourcompany.com \
  bash
```

**Clone example:**

```bash
sudo WP_PATH=/var/www/mysite WP_USER=nginx ENABLE_CLEANUP=true bash install.sh
```

| Variable | Default | Description |
| --- | --- | --- |
| `WP_PATH` | `/var/www/html` | Absolute path to WordPress root |
| `WP_USER` | `www-data` | OS user that owns WP files |
| `ENABLE_CLEANUP` | `true` | Automates `apt autoremove/autoclean` and journal log trimming |
| `CRON_SCHEDULE` | `0 3 * * 0` | Standard cron string for WP updates (Default: Sun 03:00) |
| `REBOOT_TIME` | `03:30:00` | Nightly reboot check time (UTC, format HH:MM:SS) |
| `LOG_FILE` | `/var/log/wp-auto-update.log` | WP update log path |
| `ADMIN_EMAIL` | *(empty)* | Email address for cron failure alerts (sets `MAILTO` in cron job) |
| `DRY_RUN` | `false` | Set to `true` to preview changes without applying them |

*(Note: If `ENABLE_CLEANUP` is true, the cleanup script will automatically run 30 minutes after the WordPress update to prevent CPU spikes).*

---

## Verify the install

```bash
# OS updater running?
systemctl status unattended-upgrades

# Intrusion prevention active?
systemctl status fail2ban

# Test a dry run
unattended-upgrade --dry-run

# Reboot timer scheduled?
systemctl list-timers auto-reboot.timer

# WP-CLI connected?
sudo -u www-data wp --path=/var/www/html core version

# Check scheduled jobs
cat /etc/cron.d/twdxwpss
```

---

## Logs

| What | Where |
| --- | --- |
| OS updates | `/var/log/unattended-upgrades/unattended-upgrades.log` |
| Intrusion blocks | `/var/log/fail2ban.log` |
| WP updates | `/var/log/wp-auto-update.log` |
| System Cleanup | `/var/log/vm-system-cleanup.log` |

Log files are created with mode `640` (root:adm) — not world-readable.

---

## Notes

* **Reboots** only happen when a kernel update is actually pending (`/var/run/reboot-required`). Most nightly checks will do nothing.
* **Reboots with active users** are disabled by default (`Automatic-Reboot-WithUsers "false"`). The reboot will be deferred until no users are logged in, or will happen at the scheduled time regardless — see `/etc/apt/apt.conf.d/50unattended-upgrades` to adjust.
* **WP plugin updates** flush the object cache and optimize the database automatically, but occasionally major updates can break a site. Check the log if you're actively developing.
* **Service restarts** (`needrestart`) will automatically restart MySQL, nginx, PHP-FPM, and other services after library updates. Set `$nrconf{restart} = 'i'` in `configs/needrestart.conf` if you need interactive approval.
* **Cloudflared / tunnel daemons** reconnect automatically on reboot as long as they're enabled as systemd services.
* The installer does not touch your web server, database (other than WP native optimization), or WordPress files directly — only system-level tooling is configured.
* **Cron jobs** are written to `/etc/cron.d/twdxwpss` rather than the root crontab, making them auditable as a plain file and safely overwritten on re-install.

---

## Uninstall

```bash
sudo bash uninstall.sh
```

Or manually:

```bash
# Remove cron jobs
rm -f /etc/cron.d/twdxwpss

# Disable systemd timer
systemctl disable --now auto-reboot.timer
rm /etc/systemd/system/auto-reboot.{service,timer}
systemctl daemon-reload

# Disable unattended-upgrades & fail2ban (optional — standard Ubuntu packages)
systemctl disable --now unattended-upgrades fail2ban

# Remove scripts and WP-CLI
rm /usr/local/bin/wp /usr/local/bin/wp-auto-update.sh /usr/local/bin/vm-system-cleanup.sh
rm /etc/logrotate.d/twdxwpss
```

---

## Support the Project

If this script saved you time, server costs, or weekend headaches, consider dropping a tip! It helps keep the project maintained and the open-source updates coming.

---

## License

MIT

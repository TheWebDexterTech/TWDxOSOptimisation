#!/bin/bash
# wp-auto-update.sh
# Installed by TWDxOSOptimisation (Linux RHEL/Fedora/CentOS, optional WP-CLI module)
# https://github.com/TheWebDexterTech/TWDxOSOptimisation
#
# Idempotent WordPress maintenance: core, plugin, theme, language updates,
# cache flush, transient sweep, and DB optimize. Logs every step. Exits with
# the number of failed steps so cron MAILTO surfaces partial failures.
#
# NOTE (SELinux): if WP_PATH is not under the default httpd docroot context,
# run `restorecon -Rv "$WP_PATH"` or `chcon -R -t httpd_sys_rw_content_t
# "$WP_PATH"` once after install so Apache/PHP-FPM can write to it under
# an Enforcing policy. This script does not alter SELinux contexts itself.

set -uo pipefail

WP_PATH="__WP_PATH__"
WP_USER="__WP_USER__"
LOG="__LOG_FILE__"
LOCK="/var/lock/wp-auto-update.lock"

# Single-instance guard: silently skip if another run is in progress.
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "[$(date -Iseconds)] skip: another wp-auto-update is running" >> "$LOG"
    exit 0
fi

failures=0
run() {
    local label="$1"; shift
    echo "[$(date -Iseconds)] -> $label" >> "$LOG"
    if "$@" >> "$LOG" 2>&1; then
        echo "[$(date -Iseconds)] ok   $label" >> "$LOG"
    else
        echo "[$(date -Iseconds)] FAIL $label (exit $?)" >> "$LOG"
        failures=$((failures + 1))
    fi
}

WP=(sudo -u "$WP_USER" wp --path="$WP_PATH")

{
    echo ""
    echo "=== $(date -Iseconds) START ==="
} >> "$LOG"

run "core update"          "${WP[@]}" core update
run "core update-db"       "${WP[@]}" core update-db
run "plugin update --all"  "${WP[@]}" plugin update --all
run "theme update --all"   "${WP[@]}" theme update --all
run "core language update" "${WP[@]}" core language update
run "cache flush"          "${WP[@]}" cache flush
run "transient delete"     "${WP[@]}" transient delete --all
run "db optimize"          "${WP[@]}" db optimize

echo "=== $(date -Iseconds) DONE (failures: $failures) ===" >> "$LOG"
exit "$failures"

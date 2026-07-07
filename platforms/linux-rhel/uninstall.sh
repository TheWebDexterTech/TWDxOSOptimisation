#!/bin/bash
# =============================================================================
# TWDxOSOptimisation — Linux (RHEL/Fedora/CentOS) Uninstaller
# https://github.com/TheWebDexterTech/TWDxOSOptimisation
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ ok ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
error()   { echo -e "${RED}[fail]${NC}  $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && error "Please run as root (or use sudo)."

echo -e "${CYAN}${BOLD}"
echo "  ================================================================="
echo "  TWDxOSOptimisation — Linux (RHEL/Fedora/CentOS) Uninstaller         "
echo "  ================================================================="
echo -e "${NC}"

warn "This will remove all TWDxOSOptimisation (Linux RHEL/Fedora/CentOS) components."
echo -e "  Continue? [y/N]: \c"
read -r confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

# Cron jobs
if [[ -f /etc/cron.d/twdxos ]]; then
    rm -f /etc/cron.d/twdxos
    success "Removed /etc/cron.d/twdxos"
fi

# Systemd timer and service
systemctl disable --now auto-reboot.timer 2>/dev/null || true
rm -f /etc/systemd/system/auto-reboot.service /etc/systemd/system/auto-reboot.timer
systemctl daemon-reload
success "Removed auto-reboot timer"

# dnf-automatic timer (we enabled it, we disable it — package itself is left, it's a base tool)
systemctl disable --now dnf-automatic-install.timer 2>/dev/null || true
success "Disabled dnf-automatic-install.timer"

# Scripts and locks
for f in /usr/local/bin/wp-auto-update.sh /usr/local/bin/vm-system-cleanup.sh /var/lock/wp-auto-update.lock; do
    [[ -e "$f" ]] && rm -f "$f" && success "Removed $f"
done

# WP-CLI (optional — user may want to keep it)
echo -e "  Remove WP-CLI (/usr/local/bin/wp)? [y/N]: \c"
read -r rm_wp
if [[ "$rm_wp" =~ ^[Yy]$ ]]; then
    rm -f /usr/local/bin/wp
    success "Removed WP-CLI"
fi

# Log rotation config
rm -f /etc/logrotate.d/twdxos /etc/logrotate.d/vm-auto-security
success "Removed logrotate config"

# fail2ban jail (we shipped it, we remove it)
if [[ -f /etc/fail2ban/jail.local ]]; then
    echo -e "  Remove fail2ban jail.local? [y/N]: \c"
    read -r rm_jail
    if [[ "$rm_jail" =~ ^[Yy]$ ]]; then
        rm -f /etc/fail2ban/jail.local
        systemctl restart fail2ban 2>/dev/null || true
        success "Removed fail2ban jail.local"
    fi
fi

# Disable fail2ban (optional — dnf-automatic-install.timer already disabled above)
echo -e "  Disable fail2ban? [y/N]: \c"
read -r rm_pkg
if [[ "$rm_pkg" =~ ^[Yy]$ ]]; then
    systemctl disable --now fail2ban 2>/dev/null || true
    success "Disabled fail2ban"
fi

# Kernel network hardening (harden.sh)
if [[ -f /etc/sysctl.d/99-twdxos-hardening.conf ]]; then
    rm -f /etc/sysctl.d/99-twdxos-hardening.conf
    sysctl --system > /dev/null
    success "Removed kernel hardening config and reloaded sysctl"
fi

# SSH drop-in (harden.sh)
if [[ -f /etc/ssh/sshd_config.d/99-twdxos-hardening.conf ]]; then
    rm -f /etc/ssh/sshd_config.d/99-twdxos-hardening.conf
    systemctl reload sshd 2>/dev/null || true
    success "Removed SSH hardening drop-in"
fi

# firewalld (harden.sh) — optional, user may have other rules
if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld; then
    echo -e "  Disable firewalld? [y/N]: \c"
    read -r rm_fw
    if [[ "$rm_fw" =~ ^[Yy]$ ]]; then
        systemctl disable --now firewalld 2>/dev/null || true
        success "firewalld disabled"
    fi
fi

echo
echo -e "${GREEN}${BOLD}  TWDxOSOptimisation (Linux RHEL/Fedora/CentOS) has been removed.${NC}"
echo -e "  Logs remain at /var/log/wp-auto-update.log and /var/log/vm-system-cleanup.log"
echo -e "  Remove them manually if no longer needed."
echo

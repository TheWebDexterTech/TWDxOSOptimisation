#!/bin/bash
# =============================================================================
# TWDxOSOptimisation — macOS Uninstaller
# https://github.com/TheWebDexterTech/TWDxOSOptimisation
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ ok ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
error()   { echo -e "${RED}[fail]${NC}  $*" >&2; exit 1; }

[[ "$(uname -s)" != "Darwin" ]] && error "This script targets macOS only."
[[ $EUID -ne 0 ]] && error "Please run as root (use: sudo bash uninstall.sh)."

echo -e "${CYAN}${BOLD}"
echo "  ================================================================="
echo "              TWDxOSOptimisation — macOS Uninstaller                "
echo "  ================================================================="
echo -e "${NC}"

TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    TARGET_USER=$(stat -f%Su /dev/console 2>/dev/null || echo "")
fi
[[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]] && \
    error "Could not determine a non-root console user. Run via 'sudo bash uninstall.sh' as that user."
TARGET_UID=$(id -u "$TARGET_USER" 2>/dev/null) || error "User '$TARGET_USER' not found."
TARGET_HOME=$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')

warn "This will remove all TWDxOSOptimisation (macOS) components for $TARGET_USER."
echo -e "  Continue? [y/N]: \c"
read -r confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

# Scheduled declutter LaunchAgent
DECLUTTER_PLIST="$TARGET_HOME/Library/LaunchAgents/com.twdxos.declutter.plist"
if [[ -f "$DECLUTTER_PLIST" ]]; then
    launchctl bootout "gui/$TARGET_UID" "$DECLUTTER_PLIST" 2>/dev/null || true
    rm -f "$DECLUTTER_PLIST"
    success "Removed scheduled declutter.sh LaunchAgent"
fi

# declutter.sh binary
if [[ -f /usr/local/bin/twdxos-declutter.sh ]]; then
    rm -f /usr/local/bin/twdxos-declutter.sh
    success "Removed /usr/local/bin/twdxos-declutter.sh"
fi

# Optional WP-CLI module
if [[ -f /usr/local/bin/wp-auto-update.sh ]]; then
    echo -e "  Remove the optional WP-CLI module (/usr/local/bin/wp-auto-update.sh)? [y/N]: \c"
    read -r rm_wp
    if [[ "$rm_wp" =~ ^[Yy]$ ]]; then
        rm -f /usr/local/bin/wp-auto-update.sh /tmp/wp-auto-update.lock
        success "Removed WP-CLI module"
    fi
fi

# SSH hardening drop-in (harden.sh)
if [[ -f /etc/ssh/sshd_config.d/99-twdxos-hardening.conf ]]; then
    rm -f /etc/ssh/sshd_config.d/99-twdxos-hardening.conf
    if launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
        launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
    fi
    success "Removed SSH hardening drop-in"
fi

# Application Firewall (harden.sh) — optional, user may want to keep it on
if command -v /usr/libexec/ApplicationFirewall/socketfilterfw &>/dev/null; then
    echo -e "  Disable the Application Firewall? [y/N]: \c"
    read -r rm_fw
    if [[ "$rm_fw" =~ ^[Yy]$ ]]; then
        /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off >/dev/null
        success "Application Firewall disabled"
    fi
fi

echo
echo -e "${GREEN}${BOLD}  TWDxOSOptimisation (macOS) has been removed.${NC}"
echo -e "  Logs remain at \$HOME/Library/Logs/macos-declutter/."
echo -e "  Remove them manually if no longer needed."
echo

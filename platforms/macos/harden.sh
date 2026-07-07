#!/bin/bash
# =============================================================================
# TWDxOSOptimisation — macOS Server/Workstation Hardening
# https://github.com/TheWebDexterTech/TWDxOSOptimisation
#
# Hardens a Mac: SSH daemon (drop-in config, if supported by the installed
# OpenSSH build), and macOS security settings (Application Firewall,
# Gatekeeper, FileVault, screen-lock). Report-only for anything the script
# should never silently change (disk encryption, in particular).
#
# Usage:
#   sudo bash harden.sh [--dry-run] [--help]
#
# Tested: macOS 26 Tahoe, Sequoia, Sonoma — Apple Silicon + Intel
# License: MIT
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ ok ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
error()   { echo -e "${RED}[fail]${NC}  $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}▸ $*${NC}"; }
dry_run() { echo -e "${YELLOW}[dry-run]${NC}  Would: $*"; }

show_help() {
    cat <<'EOF'
TWDxOSOptimisation — macOS Hardening

Usage:
  sudo bash harden.sh [--dry-run|--check] [--help|-h]

Environment variables:
  ENABLE_APP_FIREWALL  Enable the macOS Application Firewall  [true]
  ENABLE_SSH_HARDEN    Harden sshd_config if Include is supported [true]
  DRY_RUN              Preview without applying                [false]

Examples:
  sudo bash harden.sh
  sudo bash harden.sh --dry-run

This script NEVER touches FileVault (disk encryption) or Gatekeeper state —
it only reports their current status. Enabling/disabling those is left to
you, since they have user-visible tradeoffs (recovery keys, unsigned-app
policy) this script shouldn't decide on your behalf.
EOF
}

echo -e "${CYAN}${BOLD}"
echo "  ================================================================="
echo "                 TWDxOSOptimisation — macOS Hardening               "
echo "                                                                   "
echo "               Developed by: TheWebDexter.com                      "
echo "  ================================================================="
echo -e "${NC}"

DRY_RUN="${DRY_RUN:-false}"
for arg in "$@"; do
    case "$arg" in
        --help|-h)         show_help; exit 0 ;;
        --dry-run|--check) DRY_RUN="true" ;;
        *)                 warn "Unknown argument: $arg (use --help)" ;;
    esac
done
[[ "$DRY_RUN" == "true" ]] && warn "Dry-run mode: no changes will be made."

ENABLE_APP_FIREWALL="${ENABLE_APP_FIREWALL:-true}"
ENABLE_SSH_HARDEN="${ENABLE_SSH_HARDEN:-true}"

validate_bool() {
    local val="$1" name="$2"
    if [[ "$val" != "true" && "$val" != "false" ]]; then
        error "${name} must be 'true' or 'false' (got: '${val}')"
    fi
}

step "Validating configuration"
validate_bool "$ENABLE_APP_FIREWALL" "ENABLE_APP_FIREWALL"
validate_bool "$ENABLE_SSH_HARDEN"   "ENABLE_SSH_HARDEN"
success "All inputs validated"

step "Preflight Checks"
[[ "$(uname -s)" != "Darwin" ]] && error "This script targets macOS only."
[[ $EUID -ne 0 ]] && error "Please run as root (use: sudo bash harden.sh)."

# ── 1. Application Firewall ───────────────────────────────────────────────────
if [[ "$ENABLE_APP_FIREWALL" == "true" ]]; then
    step "Application Firewall"
    SOCKETFILTERFW="/usr/libexec/ApplicationFirewall/socketfilterfw"
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "$SOCKETFILTERFW --setglobalstate on"
        dry_run "$SOCKETFILTERFW --setstealthmode on"
    else
        if [[ -x "$SOCKETFILTERFW" ]]; then
            "$SOCKETFILTERFW" --setglobalstate on >/dev/null
            "$SOCKETFILTERFW" --setstealthmode on >/dev/null
            success "Application Firewall enabled (stealth mode on)"
        else
            warn "$SOCKETFILTERFW not found — skipping Application Firewall step"
        fi
    fi
fi

# ── 2. SSH daemon hardening (drop-in, if supported) ──────────────────────────
if [[ "$ENABLE_SSH_HARDEN" == "true" ]]; then
    step "SSH Daemon Hardening"

    SSH_DROPIN_DIR="/etc/ssh/sshd_config.d"
    SSH_DROPIN="${SSH_DROPIN_DIR}/99-twdxos-hardening.conf"

    # Apple's OpenSSH build has shipped sshd_config.d Include support since
    # macOS Ventura (13) / OpenSSH 8.x. Verify the main config actually
    # includes the drop-in directory before relying on it — older macOS
    # releases silently ignore files dropped there.
    if [[ -f /etc/ssh/sshd_config ]] && grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/\*' /etc/ssh/sshd_config; then
        if [[ "$DRY_RUN" == "true" ]]; then
            dry_run "write ${SSH_DROPIN} (CIS-aligned, minus root/system-account lockout)"
            dry_run "validate config with: sshd -t"
            dry_run "launchctl kickstart -k system/com.openssh.sshd (if running)"
        else
            mkdir -p "$SSH_DROPIN_DIR"
            cat > "$SSH_DROPIN" <<'DROPIN_EOF'
# TWDxOSOptimisation — SSH hardening
# Loaded by sshd via Include /etc/ssh/sshd_config.d/*.conf

PermitRootLogin no
PermitEmptyPasswords no
MaxAuthTries 4
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
DROPIN_EOF
            chmod 644 "$SSH_DROPIN"

            if ! sshd -t 2>/tmp/sshd-test-err; then
                warn "sshd config validation failed — removing drop-in"
                cat /tmp/sshd-test-err >&2
                rm -f "$SSH_DROPIN" /tmp/sshd-test-err
                error "SSH hardening aborted. No changes left behind."
            fi
            rm -f /tmp/sshd-test-err

            if launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
                launchctl kickstart -k system/com.openssh.sshd
            fi
            success "SSH daemon hardened via drop-in (${SSH_DROPIN})"
        fi
    else
        warn "sshd_config does not Include ${SSH_DROPIN_DIR}/*.conf on this macOS version"
        warn "(Remote Login is also likely off by default — enable it in System Settings"
        warn "> General > Sharing if you need SSH at all). Skipping SSH hardening."
    fi
fi

# ── 3. Report-only security status (never changed automatically) ────────────
step "Security status (report only — not modified by this script)"

if command -v fdesetup &>/dev/null; then
    if fdesetup status | grep -q "FileVault is On"; then
        success "FileVault: On"
    else
        warn "FileVault: Off — consider enabling it in System Settings > Privacy & Security"
    fi
fi

if spctl --status 2>/dev/null | grep -q "assessments enabled"; then
    success "Gatekeeper: enabled"
else
    warn "Gatekeeper: disabled — consider re-enabling with 'sudo spctl --master-enable'"
fi

SCREENSAVER_DELAY=$(sudo -u "${SUDO_USER:-root}" defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo "unknown")
info "Screen saver idle time: ${SCREENSAVER_DELAY}s (set one in System Settings > Lock Screen if 'unknown' or too long)"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}────────────────────────────────────────────────────${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}  Dry-run complete — no changes were made.${NC}"
else
    echo -e "${GREEN}  Hardening complete on $(hostname)${NC}"
fi
echo -e "${BOLD}────────────────────────────────────────────────────${NC}"
echo
echo -e "${CYAN}  Thank you for using automation by TheWebDexter.com${NC}"
echo

#!/bin/bash
# =============================================================================
# TWDxOSOptimisation — macOS
# https://github.com/TheWebDexterTech/TWDxOSOptimisation
#
# Hands-off maintenance for a Mac: schedules declutter.sh (Homebrew
# maintenance, cache/log cleanup, optional macOS software updates) via
# launchd, and installs the optional WP-CLI module for local WordPress dev.
#
# Usage (One-liner):
#   curl -fsSL https://raw.githubusercontent.com/TheWebDexterTech/TWDxOSOptimisation/main/platforms/macos/install.sh | sudo bash
#
# Tested: macOS 26 Tahoe, Sequoia, Sonoma — Apple Silicon + Intel
# License: MIT
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
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
TWDxOSOptimisation — macOS Installer

Usage:
  sudo bash install.sh [--dry-run|--check] [--help|-h]

Environment variables:
  ENABLE_CLEANUP    Schedule weekly declutter.sh via launchd  [true]
  ENABLE_OS_UPDATES Pass --os-updates to the scheduled run    [false]
  DECLUTTER_TIME    Weekly run time (HH:MM:SS, local time)    [03:30:00]
  WP_PATH           Absolute path to a local WordPress root   (empty = module off)
  WP_USER           macOS user owning WP files                [current console user]
  LOG_FILE          WP update log path                        [/tmp/wp-auto-update.log]
  ADMIN_EMAIL       Unused on macOS (no MAILTO equivalent)     (empty)
  DRY_RUN           Preview without applying                  [false]

Examples:
  sudo bash install.sh
  sudo bash install.sh --dry-run
  sudo ENABLE_OS_UPDATES=true bash install.sh

Note: run this with sudo (not as a plain root shell) so the installer can
detect which macOS user's launchd GUI session should own the scheduled job
(via $SUDO_USER). declutter.sh itself does not require root — it manages
per-user Homebrew/cache/log state, escalating only for 'softwareupdate'
when --os-updates is passed.
EOF
}

# ── Branding ──────────────────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}"
echo "  ================================================================="
echo "              TWDxOSOptimisation — macOS Installer                  "
echo "                                                                   "
echo "               Developed by: TheWebDexter.com                      "
echo "  ================================================================="
echo -e "${NC}"

# ── Arg parsing ───────────────────────────────────────────────────────────────
DRY_RUN="${DRY_RUN:-false}"
for arg in "$@"; do
    case "$arg" in
        --help|-h)         show_help; exit 0 ;;
        --dry-run|--check) DRY_RUN="true" ;;
        *)                 warn "Unknown argument: $arg (use --help)" ;;
    esac
done
[[ "$DRY_RUN" == "true" ]] && warn "Dry-run mode: no changes will be made."

# ── Default Configuration ─────────────────────────────────────────────────────
ENABLE_CLEANUP="${ENABLE_CLEANUP:-true}"
ENABLE_OS_UPDATES="${ENABLE_OS_UPDATES:-false}"
DECLUTTER_TIME="${DECLUTTER_TIME:-03:30:00}"
WP_PATH="${WP_PATH:-}"
LOG_FILE="${LOG_FILE:-/tmp/wp-auto-update.log}"
REPO_URL="https://raw.githubusercontent.com/TheWebDexterTech/TWDxOSOptimisation/main/platforms/macos"

# ── SHA256 digests of every remote file this installer fetches ────────────────
declare -A FILE_CHECKSUMS=(
    ["declutter.sh"]="3d4d8ba79408b6bd8f4e5a14e8fce49676a5506a0cc8aef526cf681bb7471202"
    ["configs/com.twdxos.declutter.plist.tpl"]="5c54d16ba79e36b1687c58bb160b0407814b27655675c19f422b0829dd2c798f"
    ["modules/wp-auto-update.sh.tpl"]="b599b0f7b2efb3c762dbc527c0d21601220874253248481a1c2d0e3592c585d8"
)

# ── Input validation ──────────────────────────────────────────────────────────

validate_bool() {
    local val="$1" name="$2"
    if [[ "$val" != "true" && "$val" != "false" ]]; then
        error "${name} must be 'true' or 'false' (got: '${val}')"
    fi
}

validate_time() {
    local val="$1"
    if ! [[ "$val" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$ ]]; then
        error "DECLUTTER_TIME '$val' must be in HH:MM:SS format (e.g. 03:30:00)."
    fi
}

validate_wp_path() {
    local val="$1"
    [[ -z "$val" ]] && return 0
    if ! [[ "$val" =~ ^/[a-zA-Z0-9/_.\ \-]*$ ]]; then
        error "WP_PATH '$val' contains unsafe characters."
    fi
}

validate_wp_user() {
    local val="$1"
    [[ -z "$val" ]] && error "WP_USER must not be empty."
    if ! [[ "$val" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]{0,31}$ ]]; then
        error "WP_USER '$val' is not a valid macOS username."
    fi
}

# ── Verified download helper ───────────────────────────────────────────────────
fetch_verified() {
    local path="$1" dest="$2"
    local expected="${FILE_CHECKSUMS[$path]:-}"
    [[ -z "$expected" ]] && error "No checksum registered for '$path'. Cannot proceed safely."

    local tmp
    tmp=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" RETURN

    info "Fetching $path …"
    curl -fsSL "$REPO_URL/$path" -o "$tmp"

    local actual
    actual=$(shasum -a 256 "$tmp" | awk '{print $1}')
    if [[ "$actual" != "$expected" ]]; then
        rm -f "$tmp"
        error "Checksum mismatch for '$path'.\n  Expected: $expected\n  Got:      $actual\nAborting — the file may have been tampered with."
    fi

    mv "$tmp" "$dest"
    success "Verified and installed $(basename "$dest")"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
step "Preflight Checks"

[[ "$(uname -s)" != "Darwin" ]] && error "This installer targets macOS only."
[[ $EUID -ne 0 ]] && error "Please run as root (use: sudo bash install.sh)."

TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    TARGET_USER=$(stat -f%Su /dev/console 2>/dev/null || echo "")
fi
[[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]] && \
    error "Could not determine a non-root console user. Run via 'sudo bash install.sh' as that user."

TARGET_UID=$(id -u "$TARGET_USER" 2>/dev/null) || error "User '$TARGET_USER' not found."
TARGET_HOME=$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
[[ -z "$TARGET_HOME" ]] && error "Could not determine home directory for '$TARGET_USER'."

info "Target user: $TARGET_USER (uid $TARGET_UID, home $TARGET_HOME)"

step "Validating configuration"
validate_bool "$ENABLE_CLEANUP"    "ENABLE_CLEANUP"
validate_bool "$ENABLE_OS_UPDATES" "ENABLE_OS_UPDATES"
validate_time "$DECLUTTER_TIME"
validate_wp_path "$WP_PATH"
[[ -n "$WP_PATH" ]] && WP_USER="${WP_USER:-$TARGET_USER}" && validate_wp_user "$WP_USER"
success "All inputs validated"

DECLUTTER_HOUR=$(cut -d: -f1 <<< "$DECLUTTER_TIME")
DECLUTTER_MINUTE=$(cut -d: -f2 <<< "$DECLUTTER_TIME")

LAUNCH_AGENTS_DIR="$TARGET_HOME/Library/LaunchAgents"
DECLUTTER_PLIST="$LAUNCH_AGENTS_DIR/com.twdxos.declutter.plist"
DECLUTTER_BIN="/usr/local/bin/twdxos-declutter.sh"

# ── 1. declutter.sh installation ──────────────────────────────────────────────
step "Installing declutter.sh"
if [[ "$DRY_RUN" == "true" ]]; then
    dry_run "install verified declutter.sh → $DECLUTTER_BIN"
else
    fetch_verified "declutter.sh" "$DECLUTTER_BIN"
    chmod 755 "$DECLUTTER_BIN"
fi

# ── 2. Scheduled declutter via launchd (LaunchAgent, runs as $TARGET_USER) ───
if [[ "$ENABLE_CLEANUP" == "true" ]]; then
    step "Scheduling declutter.sh (launchd)"

    EXTRA_ARG_ELEMENT=""
    [[ "$ENABLE_OS_UPDATES" == "true" ]] && EXTRA_ARG_ELEMENT="<string>--os-updates</string>"

    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "install verified configs/com.twdxos.declutter.plist.tpl → $DECLUTTER_PLIST"
        dry_run "launchctl bootstrap gui/$TARGET_UID $DECLUTTER_PLIST (weekly at $DECLUTTER_TIME, os-updates: $ENABLE_OS_UPDATES)"
    else
        mkdir -p "$LAUNCH_AGENTS_DIR"
        chown "$TARGET_USER" "$LAUNCH_AGENTS_DIR" 2>/dev/null || true

        PLIST_TMP=$(mktemp)
        # shellcheck disable=SC2064
        trap "rm -f '$PLIST_TMP'" EXIT
        fetch_verified "configs/com.twdxos.declutter.plist.tpl" "$PLIST_TMP"

        sed \
            -e "s|__SCRIPT_PATH__|${DECLUTTER_BIN}|g" \
            -e "s|__WEEKDAY__|0|g" \
            -e "s|__HOUR__|${DECLUTTER_HOUR}|g" \
            -e "s|__MINUTE__|${DECLUTTER_MINUTE}|g" \
            -e "s|__EXTRA_ARG_ELEMENT__|${EXTRA_ARG_ELEMENT}|g" \
            "$PLIST_TMP" > "$DECLUTTER_PLIST"

        chown "$TARGET_USER" "$DECLUTTER_PLIST"
        chmod 644 "$DECLUTTER_PLIST"

        launchctl bootout "gui/$TARGET_UID" "$DECLUTTER_PLIST" 2>/dev/null || true
        launchctl bootstrap "gui/$TARGET_UID" "$DECLUTTER_PLIST"
        success "declutter.sh scheduled weekly (Sunday $DECLUTTER_TIME, os-updates: $ENABLE_OS_UPDATES)"
    fi
else
    info "ENABLE_CLEANUP=false — skipping declutter.sh scheduling"
fi

# ── 3. Optional WP-CLI module ─────────────────────────────────────────────────
if [[ -n "$WP_PATH" ]]; then
    step "Optional WP-CLI module"
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "check/install WP-CLI via 'brew install wp-cli' (as $TARGET_USER)"
        dry_run "install verified modules/wp-auto-update.sh.tpl → /usr/local/bin/wp-auto-update.sh"
        dry_run "schedule via launchd LaunchAgent com.twdxos.wp-auto-update"
    else
        if ! sudo -u "$TARGET_USER" bash -c 'command -v wp' &>/dev/null; then
            sudo -u "$TARGET_USER" brew install wp-cli || \
                warn "Could not install wp-cli via Homebrew — install it manually and re-run."
        fi

        WP_TPL_TMP=$(mktemp)
        # shellcheck disable=SC2064
        trap "rm -f '$WP_TPL_TMP'" EXIT
        fetch_verified "modules/wp-auto-update.sh.tpl" "$WP_TPL_TMP"
        sed \
            -e "s|__WP_PATH__|${WP_PATH}|g" \
            -e "s|__WP_USER__|${WP_USER}|g" \
            -e "s|__LOG_FILE__|${LOG_FILE}|g" \
            "$WP_TPL_TMP" > /usr/local/bin/wp-auto-update.sh
        chmod 755 /usr/local/bin/wp-auto-update.sh
        success "wp-auto-update.sh installed (run it manually, or wrap it in your own launchd job)"
    fi
else
    info "WP_PATH not set — optional WP-CLI module skipped (this is the common case on macOS)"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}────────────────────────────────────────────────────${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}  Dry-run complete — no changes were made.${NC}"
else
    echo -e "${GREEN}  TWDxOSOptimisation (macOS) installed for $TARGET_USER${NC}"
fi
echo -e "${BOLD}────────────────────────────────────────────────────${NC}"
echo
echo -e "${CYAN}  Thank you for using automation by TheWebDexter.com${NC}"
echo

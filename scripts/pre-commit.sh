#!/usr/bin/env bash
# =============================================================================
# TWDxOSOptimisation — commit preflight
# https://github.com/TheWebDexterTech/TWDxOSOptimisation
#
# Runs three local checks before a commit lands on main (production):
#   1. ShellCheck on every shell script across every Bash-based platform
#      folder (matches CI)
#   2. FILE_CHECKSUMS drift              (sha256 of every file referenced by
#                                         each platforms/*/install.sh's own
#                                         FILE_CHECKSUMS array)
#   3. Secret scan on the staged diff    (AWS keys, GH tokens, OpenAI keys,
#                                         PEM private keys)
#
# This script is generic across platforms — adding a new platform folder
# with its own install.sh/FILE_CHECKSUMS requires zero edits here.
#
# One-time install:
#   ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
#   chmod +x scripts/pre-commit.sh
#
# Or run manually any time:
#   bash scripts/pre-commit.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
fail() { echo -e "${RED}[preflight] FAIL:${NC} $*" >&2; exit 1; }
ok()   { echo -e "${GREEN}[preflight]  ok :${NC} $*"; }
warn() { echo -e "${YELLOW}[preflight] warn:${NC} $*"; }
step() { echo -e "\n${BOLD}▸ $*${NC}"; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# ── 1. ShellCheck ────────────────────────────────────────────────────────────
# Recurses into every Bash-based platform folder (Windows ships PowerShell,
# not Bash, so platforms/windows is naturally excluded by the *.sh glob).
step "ShellCheck"
mapfile -t sh_files < <(find platforms scripts -type f \( -name '*.sh' -o -name '*.sh.tpl' \) 2>/dev/null | sort)
if ((${#sh_files[@]} == 0)); then
    fail "no shell scripts found under platforms/ or scripts/ — check the working tree"
fi
if command -v shellcheck >/dev/null 2>&1; then
    if ! shellcheck --severity=style --format=gcc "${sh_files[@]}"; then
        fail "shellcheck reported issues — fix them before committing"
    fi
    ok "shellcheck clean (${#sh_files[@]} files)"
else
    warn "shellcheck not installed — skipping locally (CI will still run it)"
fi

# ── 2. FILE_CHECKSUMS drift ──────────────────────────────────────────────────
# Loops over every platform's own install.sh and verifies each file its
# FILE_CHECKSUMS array references still matches on disk. No hardcoded file
# list here — each platform's install.sh is the registry of record.
step "FILE_CHECKSUMS drift"
drift=0
checked=0
for platform_install in platforms/*/install.sh; do
    [[ -f "$platform_install" ]] || continue
    platform_dir="$(dirname "$platform_install")"
    while IFS= read -r line; do
        rel_path=$(sed -E 's/^\s*\["([^"]+)"\].*/\1/' <<< "$line")
        registered=$(sed -E 's/.*"([a-f0-9]{64})".*/\1/' <<< "$line")
        full_path="$platform_dir/$rel_path"
        checked=$((checked + 1))
        if [[ ! -f "$full_path" ]]; then
            echo "  $full_path → referenced in $platform_install but missing from working tree"
            drift=1
            continue
        fi
        actual=$(sha256sum "$full_path" | awk '{print $1}')
        if [[ "$actual" != "$registered" ]]; then
            echo "  $full_path"
            echo "    $platform_install: $registered"
            echo "    actual              : $actual"
            drift=1
        fi
    done < <(grep -E '^\s*\["[^"]+"\]=' "$platform_install" || true)
done
if (( drift == 1 )); then
    fail "FILE_CHECKSUMS drift — update the registry in the relevant platforms/*/install.sh before committing."
fi
ok "all $checked shipped-file checksums match their platform's install.sh"

# ── 3. Secret scan on staged diff ────────────────────────────────────────────
step "Secret scan (staged diff)"
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    staged_diff=$(git diff --cached -U0)
else
    # First commit — no HEAD yet
    staged_diff=$(git diff --cached -U0 --no-index /dev/null . 2>/dev/null || true)
fi

if [[ -z "$staged_diff" ]]; then
    warn "no staged changes — running checks against working tree only"
else
    # AWS access key · GitHub PAT · OpenAI key · PEM private key block · generic password=
    pattern='(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|sk-[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|password[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']{8,})'
    if echo "$staged_diff" | grep -nEi "$pattern" >&2; then
        fail "possible secret detected in staged diff — review before committing"
    fi
    ok "no obvious secrets in staged diff"
fi

echo
echo -e "${GREEN}${BOLD}[preflight] all checks passed${NC}"

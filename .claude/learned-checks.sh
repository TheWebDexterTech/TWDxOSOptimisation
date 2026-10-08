#!/usr/bin/env bash
# =============================================================================
# TWDxOSOptimisation — learned checks (U-005)
#
# Each check: `# CHECK_NNN — description — added YYYY-MM-DD`, then a command
# block that sets fail=1 on failure. learn-from-ci.sh appends new checks
# between the LEARNED_CHECKS_START / LEARNED_CHECKS_END markers.
#
# Baseline U-005 checks that do not apply to this stack (no JS/TS, SQL, PHP or
# WordPress AJAX code in the repo): console.log, SQL interpolation, php -l,
# AJAX nonce, index.ts warning.
# =============================================================================
set -eu
cd "$(git rev-parse --show-toplevel)"

fail=0
bad() { printf '[learned-checks] FAIL %s: %s\n' "$1" "$2" >&2; fail=1; }

# LEARNED_CHECKS_START

# CHECK_001 — no hardcoded secrets in tracked files (excludes .claude/) — added 2026-10-08
if git ls-files -z -- . ':!:.claude/' | xargs -0 grep -nIE \
    '(sk_live_[0-9A-Za-z]{10,}|AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' 2>/dev/null; then
    bad CHECK_001 "possible secret in a tracked file"
fi

# CHECK_002 — .husky/pre-commit must stay POSIX sh (Husky v9 runs it with sh -e) — added 2026-10-08
if grep -nE 'pipefail|echo -e|<<<|\[\[' .husky/pre-commit; then
    bad CHECK_002 ".husky/pre-commit uses a bash-only construct"
fi

# CHECK_003 — hook and .claude shell scripts are committed as 755 — added 2026-10-08
for f in .husky/pre-commit .claude/learned-checks.sh .claude/scripts/*.sh; do
    mode=$(git ls-files -s -- "$f" | awk '{print $1}')
    if [ -n "$mode" ] && [ "$mode" != "100755" ]; then
        bad CHECK_003 "$f is mode $mode, expected 100755 (git update-index --chmod=+x)"
    fi
done

# CHECK_004 — platform folders never source or reference another platform folder — added 2026-10-08
for p in platforms/*/; do
    name=$(basename "$p")
    for other in platforms/*/; do
        o=$(basename "$other")
        [ "$o" = "$name" ] && continue
        if grep -rnE "(source|\.)[[:space:]]+[^#]*\.\./${o}/|platforms/${o}/" "$p" \
            --include='*.sh' --include='*.tpl' --include='*.ps1' 2>/dev/null; then
            bad CHECK_004 "$name references platforms/$o (platforms must stay independent)"
        fi
    done
done

# LEARNED_CHECKS_END

if [ "$fail" -ne 0 ]; then
    exit 1
fi
printf '[learned-checks] all checks passed\n'

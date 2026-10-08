#!/usr/bin/env bash
# =============================================================================
# learn-from-ci.sh — turn a CI failure log into a local learned check (U-004)
#
#   bash .claude/scripts/learn-from-ci.sh --ci-log combined.log
#
# Recognises ShellCheck codes ([SCnnnn]) and PSScriptAnalyzer rule names
# (PSAvoid…/PSUse…/PSReview…). For each new code it appends a CHECK_NNN to
# .claude/learned-checks.sh so the same pattern fails locally next time.
# Also record the fix in the TWDxMCP known-issues node.
# =============================================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

log=""
while (($#)); do
    case "$1" in
        --ci-log) log="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done
[[ -n "$log" && -f "$log" ]] || { printf 'usage: %s --ci-log <file>\n' "$0" >&2; exit 2; }

checks=.claude/learned-checks.sh
today=$(date +%F)
added=0

next_id() {
    local n
    n=$(grep -oE '^# CHECK_[0-9]{3}' "$checks" | sed 's/# CHECK_//' | sort -n | tail -1)
    printf '%03d' $((10#${n:-0} + 1))
}

append_check() {
    local key="$1" desc="$2" body="$3" id block
    if grep -qF "[$key]" "$checks"; then
        printf 'already learned: %s\n' "$key"
        return
    fi
    id=$(next_id)
    body=${body//__ID__/CHECK_$id}
    block=$(printf '# CHECK_%s — %s [%s] — added %s\n%s\n' "$id" "$desc" "$key" "$today" "$body")
    awk -v blk="$block" '/^# LEARNED_CHECKS_END/ { print blk; print "" } { print }' "$checks" > "$checks.tmp"
    cat "$checks.tmp" > "$checks" && rm -f "$checks.tmp"
    printf 'learned CHECK_%s for %s\n' "$id" "$key"
    added=$((added + 1))
}

while IFS= read -r code; do
    append_check "$code" "ShellCheck $code seen in CI" \
"if command -v shellcheck >/dev/null 2>&1; then
    git ls-files -z -- 'platforms/*.sh' 'platforms/*.sh.tpl' 'scripts/*.sh' '.claude/*.sh' \\
        | xargs -0 shellcheck --include=$code --format=gcc || bad __ID__ \"ShellCheck $code\"
fi"
done < <(grep -oE '\[SC[0-9]{4}\]' "$log" | tr -d '[]' | sort -u)

while IFS= read -r rule; do
    append_check "$rule" "PSScriptAnalyzer $rule seen in CI" \
"if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -Command \"if ((Invoke-ScriptAnalyzer -Path platforms/windows -Recurse -IncludeRule $rule).Count -gt 0) { exit 1 }\" \\
        || bad __ID__ \"PSScriptAnalyzer $rule\"
fi"
done < <(grep -oE '\bPS(Avoid|Use|Review|Possible|Misleading|Should|Place|Provide|Reserved|DSC)[A-Za-z]+' "$log" | sort -u)

printf '%d new check(s) added to %s\n' "$added" "$checks"

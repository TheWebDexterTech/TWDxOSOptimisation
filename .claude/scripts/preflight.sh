#!/usr/bin/env bash
# Full manual preflight: learned checks, repo commit preflight (ShellCheck,
# FILE_CHECKSUMS drift, staged-diff secret scan) and PSScriptAnalyzer when
# pwsh is available. CI runs this same script.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

bash .claude/learned-checks.sh
bash scripts/pre-commit.sh

if command -v pwsh >/dev/null 2>&1; then
    # shellcheck disable=SC2016  # PowerShell variables, not shell expansions
    pwsh -NoProfile -Command '
        if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { Install-Module PSScriptAnalyzer -Force -Scope CurrentUser }
        $r = Invoke-ScriptAnalyzer -Path platforms/windows -Recurse -Severity Warning,Error -Settings platforms/windows/PSScriptAnalyzerSettings.psd1
        $r | Format-Table -AutoSize
        if ($r.Count -gt 0) { exit 1 }'
else
    printf '[preflight] pwsh not installed: PSScriptAnalyzer skipped locally (CI runs it)\n'
fi

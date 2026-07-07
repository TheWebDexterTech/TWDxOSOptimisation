# TWDxOSOptimisation - PSScriptAnalyzer settings for platforms/windows/
#
# ExcludeRules:
#   PSAvoidUsingWriteHost - these scripts are interactive admin CLI tools
#   (install/harden/declutter/uninstall), not library functions meant to be
#   piped or run non-interactively. Colored Write-Host output is the direct
#   PowerShell equivalent of the info/success/warn/error color palette used
#   by the Bash platforms in this repo - an intentional UX choice, not an
#   oversight. See platforms/windows/CLAUDE.md's Conventions table.
@{
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )
}

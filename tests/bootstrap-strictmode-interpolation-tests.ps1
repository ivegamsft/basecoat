$ErrorActionPreference = 'Stop'

# Regression guard for issue #3367.
#
# PowerShell treats '?' as a valid variable-name character (e.g. the automatic
# variable $?). Inside a double-quoted string, "$mode?" is therefore parsed as a
# reference to a variable literally named 'mode?', which is undefined. Under
# Set-StrictMode -Version Latest this throws and aborts the script -- which is
# exactly how the published v4.4.0 bootstrap stopped before copying any files.
#
# The fix is to brace the variable so the '?' is a literal: "${mode}?".
# This suite fails if any executed script reintroduces the unbraced antipattern.

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

# Scripts under scripts/ (and top-level sync/bootstrap entrypoints) are the ones
# that run under strict mode on consumer machines. The tests/ tree is excluded
# because fixtures legitimately reference the antipattern regex as data.
$scanRoots = @(
    (Join-Path $repoRoot 'scripts'),
    $repoRoot
)

$scripts = New-Object System.Collections.Generic.List[string]
foreach ($root in $scanRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem -Path $root -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike (Join-Path $repoRoot 'tests') + '*' } |
        ForEach-Object { $scripts.Add($_.FullName) }
}

# Match an unbraced variable reference immediately followed by '?'.
# The braced form ${var}? does not match because it begins with '${'.
$antipattern = '\$[A-Za-z_][A-Za-z0-9_]*\?'

$violations = New-Object System.Collections.Generic.List[string]
foreach ($script in ($scripts | Sort-Object -Unique)) {
    $lineNumber = 0
    foreach ($line in (Get-Content -LiteralPath $script)) {
        $lineNumber++
        $trimmed = $line.TrimStart()
        if ($trimmed.StartsWith('#')) { continue }
        if ($line -match $antipattern) {
            $rel = $script.Substring($repoRoot.Path.Length).TrimStart('\', '/')
            $violations.Add("$rel : $lineNumber : $($line.Trim())")
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host 'Unbraced $var? interpolation found (breaks under Set-StrictMode). Use ${var}? instead:' -ForegroundColor Red
    $violations | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    throw "Strict-mode interpolation guard failed with $($violations.Count) violation(s)."
}

Write-Host "Bootstrap strict-mode interpolation tests passed ($($scripts.Count) scripts scanned)"

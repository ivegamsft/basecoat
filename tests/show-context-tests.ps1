$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$failures = @()

Write-Host 'Running show-context tests...'

# Test 1: Expected skill/instruction collisions remain present as a known pattern
$skillNames = @(Get-ChildItem (Join-Path $repoRoot 'skills') -Directory | Select-Object -ExpandProperty Name)
$instructionNames = @(Get-ChildItem (Join-Path $repoRoot 'instructions') -Filter '*.instructions.md' -File | ForEach-Object {
    $_.BaseName -replace '\.instructions$', ''
})
$collisions = @($skillNames | Where-Object { $_ -in $instructionNames } | Sort-Object -Unique)
$expectedCollisions = @('architecture', 'documentation', 'observability', 'security', 'ux')

foreach ($name in $expectedCollisions) {
    if ($name -notin $collisions) {
        $failures += "Expected collision '$name' not found between skills/ and instructions/"
    }
}

# Test 2: show-context JSON includes disambiguated source label for collision entries
$jsonOutput = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/show-context.ps1') -Agent github-security-posture -Json
$context = ($jsonOutput -join "`n") | ConvertFrom-Json
$securityItems = @($context.items | Where-Object { $_.name -eq 'security' })

if ($securityItems.Count -lt 2) {
    $failures += "Expected both skill and instruction entries for 'security' in show-context output"
}
else {
    $securityTypes = @($securityItems | ForEach-Object { $_.type } | Sort-Object -Unique)
    foreach ($requiredType in @('instruction', 'skill')) {
        if ($requiredType -notin $securityTypes) {
            $failures += "Expected 'security' entries to include type '$requiredType'"
        }
    }

    foreach ($entry in $securityItems) {
        if ([string]::IsNullOrWhiteSpace($entry.sourceLabel)) {
            $failures += "Missing sourceLabel for security/$($entry.type)"
            continue
        }
        if ($entry.sourceLabel -notmatch "^$([regex]::Escape($entry.type))@") {
            $failures += "sourceLabel '$($entry.sourceLabel)' does not start with '$($entry.type)@'"
        }
    }
}

# Test 3: terminal output includes Source (type@path) heading
$terminalOutput = pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/show-context.ps1') -Agent github-security-posture
if (($terminalOutput -join "`n") -notmatch 'Source \(type@path\)') {
    $failures += "Terminal output missing 'Source (type@path)' column heading"
}

if ($failures.Count -gt 0) {
    Write-Host "show-context tests FAILED ($($failures.Count) issue(s))" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'show-context tests passed' -ForegroundColor Green
exit 0

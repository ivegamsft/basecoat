#!/usr/bin/env pwsh
param()
$ErrorActionPreference = 'Stop'
$path = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) 'docs\reference\governance\tracker-mutation-gates.md'
$text = Get-Content $path -Raw
$failures = @()
foreach ($value in @('read-only', 'routine-write', 'acknowledgement-gated', 'human-review-gated', 'mutation_class:', 'gate_source:', 'decision: <write|block|draft-only>', 'Do not silently downgrade', 'Missing permission')) {
    if ($text -notmatch [regex]::Escape($value)) { $failures += "missing '$value'" }
}
$cases = @(
    @{ Name='routine'; Tier='routine-write'; Gate=$true; Fresh=$true; Permission=$true; Expected='write' },
    @{ Name='ack-missing'; Tier='acknowledgement-gated'; Gate=$false; Fresh=$true; Permission=$true; Expected='block' },
    @{ Name='review-present'; Tier='human-review-gated'; Gate=$true; Fresh=$true; Permission=$true; Expected='write' },
    @{ Name='stale'; Tier='routine-write'; Gate=$true; Fresh=$false; Permission=$true; Expected='block' },
    @{ Name='permission-missing'; Tier='routine-write'; Gate=$true; Fresh=$true; Permission=$false; Expected='block' }
)
foreach ($case in $cases) {
    $actual = if (-not $case.Permission -or -not $case.Fresh -or (($case.Tier -ne 'routine-write') -and -not $case.Gate)) { 'block' } else { 'write' }
    if ($actual -ne $case.Expected) { $failures += "$($case.Name) expected $($case.Expected), got $actual" }
}
if ($failures.Count) { $failures | ForEach-Object { Write-Host $_ -ForegroundColor Red }; exit 1 }
Write-Host 'Tracker mutation gates contract passed.' -ForegroundColor Green

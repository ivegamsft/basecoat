#!/usr/bin/env pwsh
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$referencePath = Join-Path $repoRoot 'docs\reference\governance\task-provenance.md'
$skillPath = Join-Path $repoRoot 'skills\task-provenance\SKILL.md'
$evalPath = Join-Path $repoRoot 'skills\task-provenance\eval.yaml'
$failures = @()

foreach ($path in @($referencePath, $skillPath, $evalPath)) {
    if (-not (Test-Path $path)) { $failures += "missing $path" }
}

foreach ($required in @('research.md', 'plan.md', 'changes.md', 'review.md', 'task_id:', 'artifact_type:', 'source_refs:', 'recorded_at:', 'owner:', 'takes precedence over conversational memory')) {
    if ((Get-Content $referencePath -Raw) -notmatch [regex]::Escape($required)) {
        $failures += "reference missing '$required'"
    }
}

foreach ($required in @('never create empty placeholders', 'File evidence takes precedence', 'Never store secrets', 'does not replace')) {
    if ((Get-Content $skillPath -Raw) -notmatch [regex]::Escape($required)) {
        $failures += "skill missing '$required'"
    }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'Task provenance contract passed.' -ForegroundColor Green

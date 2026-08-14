#!/usr/bin/env pwsh
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running adoption metrics parser tests...'

$modulePath = (Join-Path $repoRoot 'scripts\metrics\repo_inputs.py')
$collectorPath = (Join-Path $repoRoot 'scripts\metrics\collect-metrics.py')
$fixturePath = (Join-Path $repoRoot 'tests\fixtures\adoption-metrics\scalar-repo.json')

$testScript = @"
import importlib.util

module_path = r'''$modulePath'''
spec = importlib.util.spec_from_file_location('repo_inputs', module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

cases = [
    ('org/repo', ['org/repo']),
    ('["org/repo1", "org/repo2"]', ['org/repo1', 'org/repo2']),
    ('org/repo1, org/repo2;org/repo3', ['org/repo1', 'org/repo2', 'org/repo3']),
    ('  org/repo4  ', ['org/repo4']),
]

for raw, expected in cases:
    actual = module.normalize_dashboard_repos(raw)
    if actual != expected:
        raise SystemExit(f'{raw!r} -> {actual!r}, expected {expected!r}')

collector_path = r'''$collectorPath'''
collector_spec = importlib.util.spec_from_file_location('collect_metrics', collector_path)
collector = importlib.util.module_from_spec(collector_spec)
collector_spec.loader.exec_module(collector)

fixture_path = r'''$fixturePath'''
import json
with open(fixture_path, 'r', encoding='utf-8') as handle:
    metrics = json.load(handle)

summary = collector.render_summary(metrics)
if summary.count('| org/repo |') != 1:
    raise SystemExit(f'expected exactly one full repo row, got:\n{summary}')
if '| repo |' in summary:
    raise SystemExit(f'shortened repo row detected:\n{summary}')

print('Adoption metrics parser tests passed')
"@

$output = $testScript | python -
if ($LASTEXITCODE -ne 0) {
    throw "Adoption metrics parser tests failed: $output"
}

Write-Host $output

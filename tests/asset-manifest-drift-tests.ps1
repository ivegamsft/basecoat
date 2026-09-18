#!/usr/bin/env pwsh
# Tests for scripts/validate-asset-manifest-drift.ps1 (#3374 spec step 3).
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$validator = Join-Path $repoRoot 'scripts/validate-asset-manifest-drift.ps1'
$manifestPath = Join-Path $repoRoot 'asset-manifest.json'

if (-not (Test-Path $validator)) { throw "Drift validator not found: $validator" }
if (-not (Test-Path $manifestPath)) { throw "asset-manifest.json not found: $manifestPath" }

function Invoke-Drift {
    param([string]$Root)
    $failed = $false
    try { & $validator -RootDir $Root *> $null } catch { $failed = $true }
    return -not $failed
}

$failures = @()

# 1. Positive: the real repository tree must be in sync with its committed manifest.
if (-not (Invoke-Drift -Root $repoRoot)) {
    $failures += 'real repository manifest reported as drifted (expected in sync)'
}

# 2. Positive: an unmodified copy of the manifest in an alternate RootDir passes,
#    because regeneration reads the real tree and matches the committed copy.
$copyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("am-drift-" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $copyRoot | Out-Null
    Copy-Item $manifestPath (Join-Path $copyRoot 'asset-manifest.json')
    if (-not (Invoke-Drift -Root $copyRoot)) {
        $failures += 'faithful manifest copy reported as drifted (expected in sync)'
    }
}
finally { if (Test-Path $copyRoot) { Remove-Item -Recurse -Force $copyRoot } }

# 3. Negative cases: a tampered committed manifest must be detected as drift.
$tamperCases = @(
    @{ desc = 'tampered libraryVersion'; mutate = { param($m) $m.libraryVersion = '99.99.99'; $m } },
    @{ desc = 'tampered schemaVersion'; mutate = { param($m) $m.schemaVersion = '0.0'; $m } },
    @{ desc = 'tampered asset sha'; mutate = { param($m) $m.assets[0].sha = ('0' * 40); $m } },
    @{ desc = 'extra (stale) asset in committed manifest'; mutate = {
            param($m)
            $fake = [PSCustomObject]@{ path = 'skills/__does_not_exist__/SKILL.md'; type = 'skill'; sha = ('a' * 40); version = $null; effectiveVersion = $m.libraryVersion; versionSource = 'library' }
            $m.assets = @($m.assets) + $fake
            $m
        }
    },
    @{ desc = 'asset dropped from committed manifest'; mutate = {
            param($m)
            $m.assets = @($m.assets | Select-Object -Skip 1)
            $m
        }
    }
)

foreach ($case in $tamperCases) {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("am-drift-" + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        $m = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $m = & $case.mutate $m
        ($m | ConvertTo-Json -Depth 8) | Out-File -FilePath (Join-Path $root 'asset-manifest.json') -Encoding utf8
        if (Invoke-Drift -Root $root) {
            $failures += "case '$($case.desc)': expected drift to be detected but validator passed"
        }
    }
    finally { if (Test-Path $root) { Remove-Item -Recurse -Force $root } }
}

# 4. No-op guard: when the generator is absent beside the validator (as in an
#    installed/consumer copy), the check must skip rather than fail.
$noGenRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("am-drift-nogen-" + [guid]::NewGuid().ToString('N'))
try {
    $scriptsDir = Join-Path $noGenRoot 'scripts'
    New-Item -ItemType Directory -Force -Path $scriptsDir | Out-Null
    Copy-Item $validator (Join-Path $scriptsDir 'validate-asset-manifest-drift.ps1')
    # Deliberately malformed manifest: the guard must return before reading it.
    Set-Content -Path (Join-Path $noGenRoot 'asset-manifest.json') -Value 'not even json'
    $isolated = Join-Path $scriptsDir 'validate-asset-manifest-drift.ps1'
    $ok = $true
    try { & $isolated -RootDir $noGenRoot *> $null } catch { $ok = $false }
    if (-not $ok) {
        $failures += 'no-op guard: validator failed when generator was absent (expected skip)'
    }
}
finally { if (Test-Path $noGenRoot) { Remove-Item -Recurse -Force $noGenRoot } }

if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Host "FAIL: $f" -ForegroundColor Red }
    throw "asset-manifest-drift-tests: $($failures.Count) failure(s)"
}

Write-Host "asset-manifest-drift-tests: all checks passed"

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract tests for non-negotiable enforced controls.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$validatePath = Join-Path $repoRoot 'scripts\validate-basecoat.ps1'
$inventoryPath = Join-Path $repoRoot 'docs\reference\governance\enforced-controls.md'
$validateText = Get-Content $validatePath -Raw

Write-Host 'Running enforced controls contract tests...'

$failures = @()

if (-not (Test-Path $inventoryPath)) {
    $failures += 'missing docs/reference/governance/enforced-controls.md'
} else {
    $inventory = Get-Content $inventoryPath -Raw
    foreach ($control in @('LOG-FIRST issue evidence', 'Routine PR size limit', 'Config secret examples')) {
        if ($inventory -notmatch [regex]::Escape($control)) {
            $failures += "control inventory missing '$control'"
        }
    }
}

if ($validateText -notmatch 'function Test-ConfigSecretExamples') {
    $failures += 'validate-basecoat.ps1 must define Test-ConfigSecretExamples'
}

if ($validateText -notmatch 'Test-ConfigSecretExamples') {
    $failures += 'validate-basecoat.ps1 must call Test-ConfigSecretExamples'
}

if ($validateText -notmatch 'function Test-JsonConfigSecrets') {
    $failures += 'validate-basecoat.ps1 must recursively inspect JSON config templates'
}

if ($validateText -notmatch 'ConvertFrom-Json') {
    $failures += 'validate-basecoat.ps1 must parse JSON config templates instead of relying only on flat line scans'
}

foreach ($envPath in @('.env.example', 'portal\app\backend\.env.example', 'portal\backend\.env.example')) {
    $fullPath = Join-Path $repoRoot $envPath
    if (-not (Test-Path $fullPath)) {
        continue
    }

    $lineNumber = 0
    foreach ($line in Get-Content $fullPath) {
        $lineNumber++
        if ($line -match '^\s*#' -or $line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_-]*?)\s*=\s*(.+?)\s*$') {
            continue
        }

        $name = $matches[1]
        $value = $matches[2].Trim().Trim('"').Trim("'")
        if ($name -match '(?i)(secret|password|passwd|pwd|token|api[_-]?key|connection[_-]?string|instrumentation[_-]?key|client[_-]?secret|private[_-]?key)' -and
            $value -notmatch '^(<[^>]+>|\$\{[^}]+\}|your[-_a-z0-9]*|replace[-_a-z0-9]*|change[-_a-z0-9]*|example[-_a-z0-9]*|dummy[-_a-z0-9]*|placeholder[-_a-z0-9]*|todo[-_a-z0-9]*|redacted|not-set|unset)$') {
            $failures += "${envPath}:${lineNumber} ${name} must use a placeholder value"
        }
    }
}

$fixtureRoot = Join-Path $repoRoot 'test-results\enforced-controls-fixture'
if (Test-Path $fixtureRoot) {
    Remove-Item -Path $fixtureRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
try {
    Set-Content -Path (Join-Path $fixtureRoot '.env.example') -Value @'
DB_PASSWORD=<your-db-password>
TOKEN_TYPE=Bearer
'@
    Set-Content -Path (Join-Path $fixtureRoot 'sample-config.json') -Value @'
{
  "auth": {
    "clientSecret": "<your-client-secret>",
    "metadata": {
      "token_type": "Bearer"
    }
  }
}
'@
    Set-Content -Path (Join-Path $fixtureRoot 'sample-config.yml') -Value @'
id-token: write
apiKey: <your-api-key>
'@

    $secretPattern = '(?i)(secret|password|passwd|pwd|token|api[_-]?key|connection[_-]?string|instrumentation[_-]?key|client[_-]?secret|private[_-]?key)'
    $nonSecretPattern = '(?i)^(id-token|token_type|inputTokens|requiredSecrets|secret_permissions)$'
    $placeholderPattern = '^(<[^>]+>|\$\{\{[^}]+}}\s*|\$\{[^}]+\}|your[-_a-z0-9]*|replace[-_a-z0-9]*|change[-_a-z0-9]*|example[-_a-z0-9]*|dummy[-_a-z0-9]*|placeholder[-_a-z0-9]*|todo[-_a-z0-9]*|redacted|not-set|unset)$'

    $fixtureViolations = @()
    foreach ($file in Get-ChildItem -Path $fixtureRoot -File) {
        if ($file.Extension -eq '.json') {
            $json = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            $clientSecret = $json.auth.clientSecret
            if ($clientSecret -notmatch $placeholderPattern) {
                $fixtureViolations += 'sample-config.json clientSecret placeholder was not recognized'
            }
            continue
        }

        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_-]*?)\s*[:=]\s*(.+?)\s*$') {
                continue
            }
            $name = $matches[1]
            $value = $matches[2].Trim()
            if ($name -match $secretPattern -and $name -notmatch $nonSecretPattern -and $value -notmatch $placeholderPattern) {
                $fixtureViolations += "$($file.Name) $name should use a placeholder"
            }
        }
    }

    if ($fixtureViolations.Count -gt 0) {
        $failures += $fixtureViolations
    }
} finally {
    if (Test-Path $fixtureRoot) {
        Remove-Item -Path $fixtureRoot -Recurse -Force
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Enforced controls contract FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Enforced controls contract passed.' -ForegroundColor Green

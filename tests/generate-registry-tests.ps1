$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'scripts' 'generate-registry.ps1'

if (-not (Test-Path $scriptPath)) {
    throw "Script not found: $scriptPath"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('basecoat-registry-test-' + [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $agentsDir = Join-Path $tempRoot 'agents'
    $outputDir = Join-Path $tempRoot 'out'
    New-Item -ItemType Directory -Path $agentsDir | Out-Null
    New-Item -ItemType Directory -Path $outputDir | Out-Null

    @'
---
name: model-test-agent
description: Ensures model frontmatter is propagated.
model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-model-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registryPath = Join-Path $outputDir 'basecoat-registry.json'
    if (-not (Test-Path $registryPath)) {
        throw 'Registry output was not generated'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $entry = $registry.agents.'model-test-agent'
    if (-not $entry) {
        throw 'Expected model-test-agent registry entry not found'
    }
    if ($entry.model -ne 'gpt-5.3-codex') {
        throw "Expected model gpt-5.3-codex, got $($entry.model)"
    }

    Write-Host 'Generate registry tests passed'
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

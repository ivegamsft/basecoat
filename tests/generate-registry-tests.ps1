$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'scripts' 'generate-registry.ps1'

if (-not (Test-Path $scriptPath)) {
    throw "Script not found: $scriptPath"
}

$tempRoot = Join-Path $PSScriptRoot 'tmp-generate-registry-tests'
if (Test-Path $tempRoot) {
    Remove-Item -Path $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $agentsDir = Join-Path $tempRoot 'agents'
    New-Item -ItemType Directory -Path $agentsDir | Out-Null

    @'
---
name: alpha-agent
description: Alpha fixture
visibility: basic
model: gpt-5.3-codex
---
'@ | Set-Content -Path (Join-Path $agentsDir 'alpha-agent.agent.md') -Encoding UTF8

    @'
---
name: beta-agent
description: Beta fixture
visibility: basic
model: "claude-haiku-4.5"
---
'@ | Set-Content -Path (Join-Path $agentsDir 'beta-agent.agent.md') -Encoding UTF8

    @'
---
name: gamma-agent
description: Gamma fixture
visibility: basic
---
'@ | Set-Content -Path (Join-Path $agentsDir 'gamma-agent.agent.md') -Encoding UTF8

    $outputPath = Join-Path $tempRoot 'basecoat-registry.json'
    & pwsh -NoProfile -File $scriptPath -AgentsPath $agentsDir -OutputPath $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    if (-not (Test-Path $outputPath)) {
        throw 'Registry output was not generated'
    }

    $registry = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
    if ($registry.agents.'alpha-agent'.model -ne 'gpt-5.3-codex') {
        throw "Expected alpha-agent model to be gpt-5.3-codex, got '$($registry.agents.'alpha-agent'.model)'"
    }

    if ($registry.agents.'beta-agent'.model -ne 'claude-haiku-4.5') {
        throw "Expected beta-agent model to be claude-haiku-4.5, got '$($registry.agents.'beta-agent'.model)'"
    }

    if ($registry.agents.'gamma-agent'.model -ne 'claude-sonnet-4.6') {
        throw "Expected gamma-agent default model to be claude-sonnet-4.6, got '$($registry.agents.'gamma-agent'.model)'"
    }

    Write-Host 'Generate registry tests passed'
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

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
name: defaulted
description: should fallback to default model
model: claude-opus-4.8
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-10-core-defaulted.agent.md') -Encoding UTF8

    @'
---
name: allowed-model
description: allowlisted model should fallback when disabled
model: GPT-5.3-Codex
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-10-core-allowed-model.agent.md') -Encoding UTF8

    @'
---
name: pinned-precedence
description: pinned_model should win over legacy model hint
pinned_model: gpt-5.4-mini
model: claude-opus-4.8
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-10-core-pinned-precedence.agent.md') -Encoding UTF8

    @'
---
name: disabled-model
description: disabled models should fallback safely
model: gpt-5.3-codex
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-10-core-disabled-model.agent.md') -Encoding UTF8

    $registryPath = Join-Path $tempRoot 'basecoat-registry.json'
    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath $registryPath `
        -DisabledModels @('gpt-5.3-codex')

    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    if (-not (Test-Path $registryPath)) {
        throw 'Registry file was not generated'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json

    $defaulted = $registry.agents.defaulted
    if ($defaulted.model -ne 'claude-sonnet-4.6') {
        throw "Expected defaulted model to fallback to claude-sonnet-4.6, got '$($defaulted.model)'"
    }

    $allowed = $registry.agents.'allowed-model'
    if ($allowed.model -ne 'claude-sonnet-4.6') {
        throw "Expected disabled allowlisted model to fallback to claude-sonnet-4.6, got '$($allowed.model)'"
    }

    $pinned = $registry.agents.'pinned-precedence'
    if ($pinned.model -ne 'gpt-5.4-mini') {
        throw "Expected pinned model to resolve to gpt-5.4-mini, got '$($pinned.model)'"
    }

    $disabled = $registry.agents.'disabled-model'
    if ($disabled.model -ne 'claude-sonnet-4.6') {
        throw "Expected disabled model to fallback to claude-sonnet-4.6, got '$($disabled.model)'"
    }

    Write-Host 'Generate registry tests passed'
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

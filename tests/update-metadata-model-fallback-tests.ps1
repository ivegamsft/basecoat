$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'scripts' 'update-metadata.ps1'

if (-not (Test-Path $scriptPath)) {
    throw "Script not found: $scriptPath"
}

$tempRoot = Join-Path $PSScriptRoot 'tmp-update-metadata-model-fallback-tests'
if (Test-Path $tempRoot) {
    Remove-Item -Path $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRoot | Out-Null

$pushedLocation = $false

try {
    $agentsDir = Join-Path $repoRoot 'agents'
    $testSuffix = [Guid]::NewGuid().ToString('N').Substring(0, 8)

    $metadataPath = Join-Path $tempRoot 'basecoat-metadata.json'
    $alphaFileName = "basecoat-10-core-model-fallback-alpha-$testSuffix.agent.md"
    $betaFileName = "basecoat-10-core-model-fallback-beta-$testSuffix.agent.md"
    $gammaFileName = "basecoat-10-core-model-fallback-gamma-$testSuffix.agent.md"
    $alphaName = $alphaFileName -replace '\.agent\.md$', ''

    [ordered]@{
        version = '1.0.0'
        generated = '2026-01-01'
        categories = [ordered]@{}
        agents = @(
            [ordered]@{
                name = $alphaName
                description = 'curated alpha'
                category = 'Meta'
                keywords = @('curated')
                aliases = @()
                pairedSkill = ''
                file = "agents/$alphaFileName"
                model = 'claude-haiku-4.5'
                argumentHint = ''
            }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath -Encoding UTF8

    @'
---
name: alpha
description: alpha fixture
visibility: basic
model: claude-sonnet-4.6
---
'@ | Set-Content -Path (Join-Path $agentsDir $alphaFileName) -Encoding UTF8

    @'
---
name: beta
description: beta fixture
visibility: specialized
model: gpt-5.3-codex
---
'@ | Set-Content -Path (Join-Path $agentsDir $betaFileName) -Encoding UTF8

    @'
---
name: gamma
description: gamma fixture
visibility: basic
---
'@ | Set-Content -Path (Join-Path $agentsDir $gammaFileName) -Encoding UTF8

    Push-Location $repoRoot
    $pushedLocation = $true
    & pwsh -NoProfile -File $scriptPath -MetadataPath $metadataPath
    Pop-Location
    $pushedLocation = $false
    if ($LASTEXITCODE -ne 0) {
        throw 'update-metadata.ps1 exited with non-zero status'
    }

    $updatedMetadataRaw = Get-Content -Path $metadataPath -Raw
    $updatedMetadata = $updatedMetadataRaw | ConvertFrom-Json

    $betaName = $betaFileName -replace '\.agent\.md$', ''
    $gammaName = $gammaFileName -replace '\.agent\.md$', ''

    $alpha = $updatedMetadata.agents | Where-Object { $_.name -eq $alphaName }
    if (-not $alpha) { throw 'Expected alpha agent entry not found' }
    if ($alpha.model -ne 'claude-sonnet-4.6') {
        throw "Expected existing metadata model to synchronize to claude-sonnet-4.6, got '$($alpha.model)'"
    }
    if ('curated' -notin @($alpha.keywords)) {
        throw 'Existing curated metadata fields must be preserved while synchronizing the model'
    }

    $beta = $updatedMetadata.agents | Where-Object { $_.name -eq $betaName }
    if (-not $beta) { throw 'Expected beta agent entry not found' }
    if ($beta.model -ne 'gpt-5.3-codex') {
        throw "Expected canonical model gpt-5.3-codex for beta, got '$($beta.model)'"
    }

    $gamma = $updatedMetadata.agents | Where-Object { $_.name -eq $gammaName }
    if (-not $gamma) { throw 'Expected gamma agent entry not found' }
    if ($gamma.model -ne 'gpt-5.4-mini') {
        throw "Expected missing model fallback gpt-5.4-mini for gamma, got '$($gamma.model)'"
    }

    if ($updatedMetadataRaw -match 'GH_AW_MODEL_AGENT_COPILOT' -or $updatedMetadataRaw -match 'GH_AW_MODEL_DETECTION_COPILOT') {
        throw 'Generated metadata leaked private model policy variable names'
    }

    Write-Host 'Update metadata model fallback tests passed'
}
finally {
    if ($pushedLocation) {
        Pop-Location
    }
    Get-ChildItem -Path (Join-Path $repoRoot 'agents') -Filter "*$testSuffix.agent.md" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -Path $_.FullName -Force
    }
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

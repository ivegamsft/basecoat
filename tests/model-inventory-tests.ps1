$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'scripts' 'generate-model-inventory.ps1'

if (-not (Test-Path $scriptPath)) {
    throw "Script not found: $scriptPath"
}

$tempRoot = Join-Path $PSScriptRoot 'tmp-model-inventory-tests'
if (Test-Path $tempRoot) {
    Remove-Item -Path $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $agentsDir = Join-Path $tempRoot 'agents'
    $docsDir = Join-Path $tempRoot 'docs'
    New-Item -ItemType Directory -Path $agentsDir | Out-Null
    New-Item -ItemType Directory -Path $docsDir | Out-Null

    @'
---
name: one
description: one
model: Claude Sonnet 4.6
---
'@ | Set-Content -Path (Join-Path $agentsDir 'one.agent.md') -Encoding UTF8

    @'
---
name: two
description: two
model: claude-sonnet-4.6
---
'@ | Set-Content -Path (Join-Path $agentsDir 'two.agent.md') -Encoding UTF8

    @'
---
name: three
description: three
model: GPT-5.3-Codex
---
'@ | Set-Content -Path (Join-Path $agentsDir 'three.agent.md') -Encoding UTF8

    @'
---
name: four
description: four
model: internal-preview-model
---
'@ | Set-Content -Path (Join-Path $agentsDir 'four.agent.md') -Encoding UTF8

    @'
---
name: five
description: five
---
'@ | Set-Content -Path (Join-Path $agentsDir 'five.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -ModelMapPath (Join-Path $docsDir 'model-map.json') `
        -ModelInventoryPath (Join-Path $docsDir 'model-inventory.md')

    if ($LASTEXITCODE -ne 0) {
        throw 'generate-model-inventory.ps1 exited with non-zero status'
    }

    $mapPath = Join-Path $docsDir 'model-map.json'
    $inventoryPath = Join-Path $docsDir 'model-inventory.md'
    if (-not (Test-Path $mapPath)) { throw 'model-map.json was not generated' }
    if (-not (Test-Path $inventoryPath)) { throw 'model-inventory.md was not generated' }

    $map = Get-Content -Path $mapPath -Raw | ConvertFrom-Json
    $claude = $map.models | Where-Object { $_.canonical -eq 'claude-sonnet-4.6' }
    if (-not $claude) { throw 'Expected canonical key claude-sonnet-4.6 not found' }
    if ($claude.count -ne 2) { throw "Expected count 2 for claude-sonnet-4.6, got $($claude.count)" }
    if (-not ($claude.aliases -contains 'Claude Sonnet 4.6')) { throw 'Expected alias Claude Sonnet 4.6 not found' }
    if (-not ($claude.aliases -contains 'claude-sonnet-4.6')) { throw 'Expected alias claude-sonnet-4.6 not found' }

    $gpt = $map.models | Where-Object { $_.canonical -eq 'gpt-5.3-codex' }
    if (-not $gpt) { throw 'Expected canonical key gpt-5.3-codex not found' }
    if ($gpt.count -ne 1) { throw "Expected count 1 for gpt-5.3-codex, got $($gpt.count)" }

    $fallback = $map.models | Where-Object { $_.canonical -eq 'gpt-5.4-mini' }
    if (-not $fallback) { throw 'Expected fallback canonical key gpt-5.4-mini not found' }
    if ($fallback.count -ne 2) { throw "Expected count 2 for gpt-5.4-mini, got $($fallback.count)" }
    if (-not ($fallback.aliases -contains 'gpt-5.4-mini')) { throw 'Expected alias gpt-5.4-mini not found for missing-model fallback' }
    if ($fallback.aliases -contains 'internal-preview-model') { throw 'Unsupported model alias should not be persisted in model inventory output' }

    Write-Host 'Model inventory tests passed'
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

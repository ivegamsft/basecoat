$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scratchRoot = Join-Path $repoRoot '.scratch-generate-registry-tests'
$agentsPath = Join-Path $scratchRoot 'agents'
$outputPath = Join-Path $scratchRoot 'registry.json'

function Assert-Equal {
    param(
        [string]$Actual,
        [string]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message. Expected '$Expected', got '$Actual'."
    }
}

try {
    if (Test-Path $scratchRoot) {
        Remove-Item -Path $scratchRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $agentsPath -Force | Out-Null

    @'
---
name: allowed-model-agent
description: "allowed model"
model: gpt-5.4-mini
---
# Allowed
'@ | Set-Content -Path (Join-Path $agentsPath 'basecoat-10-core-allowed-model-agent.agent.md') -NoNewline

    @'
---
name: mapped-model-agent
description: "mapped model"
model: claude-sonnet-4.6
---
# Mapped
'@ | Set-Content -Path (Join-Path $agentsPath 'basecoat-10-core-mapped-model-agent.agent.md') -NoNewline

    @'
---
name: unknown-model-agent
description: "unknown model"
model: some-private-model
---
# Unknown
'@ | Set-Content -Path (Join-Path $agentsPath 'basecoat-10-core-unknown-model-agent.agent.md') -NoNewline

    & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts\generate-registry.ps1') -AgentsPath $agentsPath -OutputPath $outputPath

    $registry = Get-Content -Path $outputPath -Raw | ConvertFrom-Json -AsHashtable
    Assert-Equal -Actual $registry.agents['allowed-model-agent'].model -Expected 'gpt-5.4-mini' -Message 'Allowed model should remain unchanged'
    Assert-Equal -Actual $registry.agents['mapped-model-agent'].model -Expected 'claude-sonnet-4.6' -Message 'CLI-supported model should remain unchanged'
    Assert-Equal -Actual $registry.agents['unknown-model-agent'].model -Expected 'gpt-5.4-mini' -Message 'Unknown model should resolve to default fallback'

    Write-Host 'generate-registry model fallback tests passed'
}
finally {
    if (Test-Path $scratchRoot) {
        Remove-Item -Path $scratchRoot -Recurse -Force
    }
}

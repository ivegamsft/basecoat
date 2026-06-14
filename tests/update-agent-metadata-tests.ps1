$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'scripts' 'update-agent-metadata.ps1'

if (-not (Test-Path $scriptPath)) {
    throw "Script not found: $scriptPath"
}

$tempRoot = Join-Path $PSScriptRoot 'tmp-update-agent-metadata-tests'
if (Test-Path $tempRoot) {
    Remove-Item -Path $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $agentsDir = Join-Path $tempRoot 'agents'
    New-Item -ItemType Directory -Path $agentsDir | Out-Null

    @'
---
name: issue-triage
description: test fixture
visibility: basic
model: claude-haiku-4.5
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-10-core-issue-triage.agent.md') -Encoding UTF8

    @'
---
name: api-designer
description: test fixture
visibility: specialized
model: claude-sonnet-4.6
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-10-core-api-designer.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath -AgentsPath $agentsDir
    if ($LASTEXITCODE -ne 0) {
        throw 'update-agent-metadata.ps1 exited with non-zero status'
    }

    $issueTriage = Get-Content -Path (Join-Path $agentsDir 'basecoat-10-core-issue-triage.agent.md') -Raw
    if ($issueTriage -notmatch '(?m)^model:\s*gpt-5.4-mini\s*$') {
        throw 'Expected issue-triage model to be updated to gpt-5.4-mini'
    }

    $apiDesigner = Get-Content -Path (Join-Path $agentsDir 'basecoat-10-core-api-designer.agent.md') -Raw
    if ($apiDesigner -notmatch '(?m)^model:\s*gpt-5.3-codex\s*$') {
        throw 'Expected api-designer model to be set to gpt-5.3-codex'
    }

    if ($apiDesigner -match '(?m)^model:\s*claude-sonnet-4.6\s*$') {
        throw 'Expected unsupported model to be rewritten via fallback policy'
    }

    Write-Host 'Update agent metadata tests passed'
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}

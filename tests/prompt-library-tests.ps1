$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$generator = Join-Path $repoRoot 'scripts\generate-prompt-library.ps1'
$committedLibrary = Join-Path $repoRoot 'docs\reference\prompt-library.md'
$tempLibrary = Join-Path ([System.IO.Path]::GetTempPath()) ('basecoat-prompt-library-' + [System.Guid]::NewGuid().ToString() + '.md')
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('basecoat-prompt-library-fixtures-' + [System.Guid]::NewGuid().ToString())

try {
    & pwsh -NoProfile -File $generator -OutputPath $tempLibrary
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-prompt-library.ps1 exited with non-zero status'
    }

    $generated = (Get-Content -Path $tempLibrary -Raw) -replace "`r`n", "`n"
    $committed = (Get-Content -Path $committedLibrary -Raw) -replace "`r`n", "`n"
    if ($generated -ne $committed) {
        throw 'docs/reference/prompt-library.md is stale; regenerate it with scripts/generate-prompt-library.ps1'
    }

    foreach ($marker in @(
        '## Lifecycle prompts',
        '### Onboard BaseCoat',
        '### Refresh BaseCoat',
        '### Remove BaseCoat',
        '### YAGNI analysis output example',
        '## Sample outputs',
        '<!-- markdownlint-disable MD033 -->',
        '<!-- markdownlint-enable MD033 -->'
    )) {
        if ($generated -notmatch [regex]::Escape($marker)) {
            throw "Prompt library missing required section: $marker"
        }
    }

    $intentSource = Get-Content (Join-Path $repoRoot 'instructions\basecoat-10-core-intent-routing.instructions.md') -Raw
    $prefixes = [regex]::Matches($intentSource, '(?m)^\|\s*`([a-z0-9-]+:)`\s*\|') | ForEach-Object { $_.Groups[1].Value }
    foreach ($prefix in $prefixes) {
        if ($generated -notmatch [regex]::Escape("| ``$prefix`` |")) {
            throw "Prompt library missing intent prefix: $prefix"
        }
    }

    $assetPaths = @()
    $assetPaths += Get-ChildItem (Join-Path $repoRoot 'skills') -Recurse -Filter 'SKILL.md' -File
    $assetPaths += Get-ChildItem (Join-Path $repoRoot 'agents') -Filter '*.agent.md' -File
    foreach ($asset in $assetPaths) {
        $relativePath = $asset.FullName.Substring($repoRoot.Path.Length + 1).Replace('\', '/')
        if ($generated -notmatch [regex]::Escape("[$relativePath]")) {
            throw "Prompt library missing asset: $relativePath"
        }
    }

    foreach ($expectedPrompt in @(
        '@data-integrity Help me with this task: Distributed data integrity patterns',
        '@dotnet-modernization-advisor Help me with this task: Advisor for .NET modernization',
        "Use the 'sdlc-content-pack' skill. Task: generating SDLC-aligned content bundles (diagrams, click-through scripts, video scripts, decks)",
        '@hardening-advisor Help me with this task: harden Dockerfile'
    )) {
        if ($generated -notmatch [regex]::Escape($expectedPrompt)) {
            throw "Prompt library missing regression example: $expectedPrompt"
        }
    }

    if ($generated -match '@Hardening Advisor' -or $generated -match 'Task: &gt;\.') {
        throw 'Prompt library contains a non-invocable agent name or unparsed folded YAML description'
    }

    $fixtureAgents = Join-Path $fixtureRoot 'agents'
    $fixtureSkills = Join-Path $fixtureRoot 'skills'
    $fixtureSkillDirectory = Join-Path $fixtureSkills 'literal-skill'
    New-Item -ItemType Directory -Path $fixtureAgents, $fixtureSkillDirectory -Force | Out-Null
    @'
---
name: Folded Agent
description: >-
  First folded line

  second folded line.
---
'@ | Set-Content -Path (Join-Path $fixtureAgents 'folded-agent.agent.md') -Encoding utf8
    @'
---
name: literal-skill
description: |+
  USE FOR: literal block prompt

  DO NOT USE FOR: unrelated work.
compatibility: [github-copilot-cli]
---
'@ | Set-Content -Path (Join-Path $fixtureSkillDirectory 'SKILL.md') -Encoding utf8

    $fixtureLibrary = Join-Path $fixtureRoot 'prompt-library.md'
    & pwsh -NoProfile -File $generator -OutputPath $fixtureLibrary -AgentsPath $fixtureAgents -SkillsPath $fixtureSkills
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-prompt-library.ps1 failed for YAML block scalar fixtures'
    }
    $fixtureGenerated = Get-Content -Path $fixtureLibrary -Raw
    foreach ($fixturePrompt in @(
        '@folded-agent Help me with this task: First folded line second folded line.',
        "Use the 'literal-skill' skill. Task: literal block prompt."
    )) {
        if ($fixtureGenerated -notmatch [regex]::Escape($fixturePrompt)) {
            throw "Prompt library failed YAML block scalar fixture: $fixturePrompt"
        }
    }

    Write-Host "Prompt library tests passed ($($prefixes.Count) intents, $($assetPaths.Count) assets)"
}
finally {
    if (Test-Path $tempLibrary) {
        Remove-Item -Path $tempLibrary -Force
    }
    if (Test-Path $fixtureRoot) {
        Remove-Item -Path $fixtureRoot -Recurse -Force
    }
}

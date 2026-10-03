[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-dogfood-tests-$([guid]::NewGuid().ToString('N'))"
$fixtureRoot = Join-Path $scratch 'fixture'
$sourceScriptDir = Join-Path $fixtureRoot 'scripts'
$installerPath = Join-Path $sourceScriptDir 'dogfood-install.ps1'
$projectionHelperPath = Join-Path $sourceScriptDir 'dogfood-projection.ps1'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-DogfoodInstaller {
    param([switch]$Check)
    $arguments = @('-NoProfile', '-File', $installerPath, '-RootDir', $fixtureRoot)
    if ($Check) {
        $arguments += '-Check'
    }
    $output = & pwsh @arguments 2>&1 | Out-String
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = $output
    }
}

function Write-FixtureFile {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $path = Join-Path $fixtureRoot ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    Set-Content -LiteralPath $path -Value $Content -Encoding UTF8
}

try {
    New-Item -ItemType Directory -Path $sourceScriptDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/dogfood-install.ps1') -Destination $installerPath
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/dogfood-projection.ps1') -Destination $projectionHelperPath

    Write-FixtureFile -RelativePath 'skills/repo-cleanup/SKILL.md' -Content @'
---
name: repo-cleanup
description: Clean repository worktrees.
category: operations
---
Use the repository cleanup contract.
'@
    Write-FixtureFile -RelativePath 'skills/repo-cleanup/contract.md' -Content 'Preserve active work.'
    Write-FixtureFile -RelativePath 'skills/agentic-sdlc-autonomy/SKILL.md' -Content @'
---
name: agentic-sdlc-autonomy
description: Govern agent-operated development.
category: sdlc-governance
---
Use the autonomy contract.
'@
    Write-FixtureFile -RelativePath 'skills/azure-landing-zone/SKILL.md' -Content @'
---
name: azure-landing-zone
description: Plan Azure landing zones.
category: infrastructure
---
Consumer-facing skill.
'@
    Write-FixtureFile -RelativePath 'skills/api-design/SKILL.md' -Content @'
---
name: api-design
description: Design APIs.
category: architecture
---
Consumer-facing skill.
'@
    Write-FixtureFile -RelativePath 'agents/basecoat-10-core-branch-hygiene-sweeper.agent.md' -Content @'
name: branch-hygiene-sweeper
[Details](references/branch-hygiene-detail.md)
'@
    Write-FixtureFile -RelativePath 'agents/basecoat-10-core-backend-dev.agent.md' -Content 'name: backend-dev'
    Write-FixtureFile -RelativePath 'agents/flow-governance-conductor.agent.md' -Content 'name: flow-governance-conductor'
    Write-FixtureFile -RelativePath 'agents/references/branch-hygiene-detail.md' -Content 'Branch cleanup reference.'
    Write-FixtureFile -RelativePath 'prompts/code-review.prompt.md' -Content 'Review source changes.'
    Write-FixtureFile -RelativePath 'prompts/portal-github-oauth-onboarding.prompt.md' -Content 'Consumer onboarding.'
    Write-FixtureFile -RelativePath 'instructions/basecoat-core.instructions.md' -Content 'Repo metadata instruction.'
    Write-FixtureFile -RelativePath '.copilot/skills/personal/SKILL.md' -Content 'Personal skills are not projection input.'

    git -C $fixtureRoot init --quiet -b main
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize dogfood fixture repository.' }
    git -C $fixtureRoot config user.name 'basecoat-test'
    git -C $fixtureRoot config user.email 'basecoat-test@example.com'
    git -C $fixtureRoot add -A
    git -C $fixtureRoot commit --quiet -m 'seed dogfood fixture'
    if ($LASTEXITCODE -ne 0) { throw 'Could not commit dogfood fixture source assets.' }

    $initialCheck = Invoke-DogfoodInstaller -Check
    Assert-True -Condition ($initialCheck.ExitCode -ne 0) `
        -Message 'Check mode must detect a missing projection.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot '.github/skills'))) `
        -Message 'Check mode must not create destination directories.'

    $install = Invoke-DogfoodInstaller
    Assert-True -Condition ($install.ExitCode -eq 0) `
        -Message "Installer must complete for a valid source fixture. $($install.Output)"

    foreach ($destination in @(
            '.github/skills/repo-cleanup/SKILL.md',
            '.agents/skills/repo-cleanup/SKILL.md',
            '.github/skills/agentic-sdlc-autonomy/SKILL.md',
            '.github/agents/basecoat-10-core-branch-hygiene-sweeper.agent.md',
            '.github/agents/flow-governance-conductor.agent.md',
            '.github/agents/references/branch-hygiene-detail.md',
            '.github/prompts/code-review.prompt.md'
        )) {
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $fixtureRoot $destination)) `
            -Message "Installer must project the curated source asset to '$destination'."
    }
    foreach ($excluded in @(
            '.github/skills/azure-landing-zone/SKILL.md',
            '.agents/skills/azure-landing-zone/SKILL.md',
            '.github/skills/api-design/SKILL.md',
            '.github/agents/basecoat-10-core-backend-dev.agent.md',
            '.github/prompts/portal-github-oauth-onboarding.prompt.md',
            '.github/instructions/basecoat-core.instructions.md',
            '.github/skills/personal/SKILL.md'
        )) {
        Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot $excluded))) `
            -Message "Installer must not project excluded asset '$excluded'."
    }

    $currentCheck = Invoke-DogfoodInstaller -Check
    Assert-True -Condition ($currentCheck.ExitCode -eq 0) `
        -Message "Check mode must pass for a current projection. $($currentCheck.Output)"

    $outsideTarget = Join-Path $scratch 'outside-target'
    New-Item -ItemType Directory -Path $outsideTarget -Force | Out-Null
    $manifestTempPath = Join-Path $fixtureRoot '.github/.basecoat-dogfood-manifest.json.tmp'
    $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $manifestTempPath -Target $outsideTarget | Out-Null
    $reparseTemp = Invoke-DogfoodInstaller
    Assert-True -Condition ($reparseTemp.ExitCode -ne 0 -and $reparseTemp.Output -match 'symbolic link or reparse point') `
        -Message 'Installer must reject a reparse point at its temporary manifest path.'
    Remove-Item -LiteralPath $manifestTempPath -Force

    $originalPath = $env:PATH
    try {
        $env:PATH = Split-Path -Parent (Get-Command pwsh).Source
        $missingGit = Invoke-DogfoodInstaller
        Assert-True -Condition ($missingGit.ExitCode -ne 0 -and $missingGit.Output -match 'Git is required') `
            -Message 'Installer must fail explicitly when git is unavailable.'
    }
    finally {
        $env:PATH = $originalPath
    }

    $manifestPath = Join-Path $fixtureRoot '.github/.basecoat-dogfood-manifest.json'
    $manifestBefore = Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256
    $changedProjection = Join-Path $fixtureRoot '.github/agents/flow-governance-conductor.agent.md'
    Set-Content -LiteralPath $changedProjection -Value 'locally changed' -Encoding UTF8
    $staleCheck = Invoke-DogfoodInstaller -Check
    Assert-True -Condition ($staleCheck.ExitCode -ne 0) `
        -Message 'Check mode must detect modified projected content.'
    Assert-True -Condition ((Get-Content -LiteralPath $changedProjection -Raw).Trim() -eq 'locally changed') `
        -Message 'Check mode must not modify projected files.'
    Assert-True -Condition ((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -eq $manifestBefore.Hash) `
        -Message 'Check mode must not modify the projection manifest.'

    $customFile = Join-Path $fixtureRoot '.github/skills/local-only/SKILL.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $customFile) -Force | Out-Null
    Set-Content -LiteralPath $customFile -Value 'unmanaged local asset'
    $refresh = Invoke-DogfoodInstaller
    Assert-True -Condition ($refresh.ExitCode -eq 0) `
        -Message "Installer must refresh a stale projection. $($refresh.Output)"
    Assert-True -Condition ((Get-Content -LiteralPath $changedProjection -Raw).Trim() -eq 'name: flow-governance-conductor') `
        -Message 'Refresh must replace a changed managed file with its canonical source.'
    Assert-True -Condition (Test-Path -LiteralPath $customFile) `
        -Message 'Refresh must preserve unowned local assets in projected directories.'

    Remove-Item -LiteralPath (Join-Path $fixtureRoot 'skills/repo-cleanup') -Recurse -Force
    $prune = Invoke-DogfoodInstaller
    Assert-True -Condition ($prune.ExitCode -eq 0) `
        -Message "Refresh must remove stale managed assets. $($prune.Output)"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot '.github/skills/repo-cleanup/SKILL.md'))) `
        -Message 'Refresh must remove a projected skill that no longer exists canonically.'
    Assert-True -Condition (Test-Path -LiteralPath $customFile) `
        -Message 'Stale cleanup must preserve unowned local assets.'

    Write-FixtureFile -RelativePath 'skills/handoff/SKILL.md' -Content @'
---
name: handoff
description: Capture a handoff.
category: operations
---
Handoff source.
'@
    $addHandoff = Invoke-DogfoodInstaller
    Assert-True -Condition ($addHandoff.ExitCode -eq 0) `
        -Message "Installer must project a newly added curated asset. $($addHandoff.Output)"
    $handoffDestination = Join-Path $fixtureRoot '.github/skills/handoff/SKILL.md'
    Set-Content -LiteralPath $handoffDestination -Value 'locally modified stale asset' -Encoding UTF8
    Remove-Item -LiteralPath (Join-Path $fixtureRoot 'skills/handoff') -Recurse -Force
    $rejectModifiedOrphan = Invoke-DogfoodInstaller
    Assert-True -Condition ($rejectModifiedOrphan.ExitCode -ne 0) `
        -Message 'Installer must reject removal of a locally modified stale projection.'
    Assert-True -Condition (Test-Path -LiteralPath $handoffDestination) `
        -Message 'Installer must preserve a locally modified stale projection.'

    Set-Content -LiteralPath $manifestPath -Value (@{
            schemaVersion = 1
            entries = @(@{ path = '.github/skills/../../outside.txt'; sha256 = 'a' * 64 })
        } | ConvertTo-Json -Depth 5) -Encoding UTF8
    $invalidManifest = Invoke-DogfoodInstaller
    Assert-True -Condition ($invalidManifest.ExitCode -ne 0) `
        -Message 'Installer must reject traversal paths from a modified ownership manifest.'

    Write-Host 'Local Copilot dogfood projection tests passed.'
}
finally {
    if (Test-Path -LiteralPath $scratch) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$skillsDir = Join-Path $repoRoot 'skills'

if (-not (Test-Path $skillsDir)) {
    throw "Skills directory not found: $skillsDir"
}

function Get-SkillFrontmatter {
    param([string]$Content)

    if ($Content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        return $Matches[1]
    }

    return ''
}

function Get-FrontmatterScalar {
    param(
        [string]$Frontmatter,
        [string]$FieldName
    )

    $normalized = $Frontmatter -replace "`r", ''
    foreach ($line in ($normalized -split "`n")) {
        if ($line -match "^$([regex]::Escape($FieldName))\s*:\s*(.+)$") {
            return $Matches[1].Trim()
        }
    }

    return $null
}

function Split-ApplyToValues {
    param([string]$RawValue)

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return @()
    }

    $value = $RawValue.Trim()
    if ($value -match '^\[(.*)\]$') {
        $value = $Matches[1]
    }

    return @(
        $value -split '\s*,\s*' |
            ForEach-Object { $_.Trim().Trim('"', "'") } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-AgentPseudoPathApplyToValues {
    param([string]$Frontmatter)

    $applyTo = Get-FrontmatterScalar -Frontmatter $Frontmatter -FieldName 'applyTo'
    if ($null -eq $applyTo) {
        return @()
    }

    return @(Split-ApplyToValues -RawValue $applyTo | Where-Object { $_ -match '^agent-[A-Za-z0-9-]+$' })
}

$positiveApplyTo = @'
name: fixture
description: fixture
compatibility: [github-copilot-cli]
applyTo: "apps/electron/**/*, **/*.electron.ts"
'@

$negativeApplyTo = @'
name: fixture
description: fixture
compatibility: [github-copilot-cli]
applyTo: agent-electron-developer, agent-desktop-engineer
'@

if ((Get-AgentPseudoPathApplyToValues -Frontmatter $positiveApplyTo).Count -ne 0) {
    throw 'Skill applyTo pseudo-path positive fixture failed: real Electron globs were rejected'
}

$negativeMatches = @(Get-AgentPseudoPathApplyToValues -Frontmatter $negativeApplyTo)
if ('agent-electron-developer' -notin $negativeMatches) {
    throw 'Skill applyTo pseudo-path negative fixture failed: pre-fix agent-electron-developer value was not caught'
}

$missing = @()
$invalidApplyTo = @()

Get-ChildItem -Path $skillsDir -Directory | Sort-Object Name | ForEach-Object {
    $skillName = $_.Name
    $skillFile = Join-Path $_.FullName 'SKILL.md'

    if (-not (Test-Path $skillFile)) {
        $missing += "$skillName (missing SKILL.md)"
        return
    }

    $content = Get-Content -Path $skillFile -Raw
    $frontmatter = Get-SkillFrontmatter -Content $content

    if ([string]::IsNullOrWhiteSpace($frontmatter)) {
        $missing += "$skillName (missing frontmatter block)"
        return
    }

    if ($frontmatter -notmatch '(?m)^compatibility\s*:\s*\S') {
        $missing += "$skillName (missing compatibility frontmatter)"
    }

    $agentPseudoPaths = @(Get-AgentPseudoPathApplyToValues -Frontmatter $frontmatter)
    if ($agentPseudoPaths.Count -gt 0) {
        $invalidApplyTo += "$skillName (applyTo uses agent-name pseudo-paths: $($agentPseudoPaths -join ', '))"
    }
}

if ($missing.Count -gt 0) {
    $details = $missing -join '; '
    throw "Skill compatibility frontmatter check failed: $details"
}

if ($invalidApplyTo.Count -gt 0) {
    $details = $invalidApplyTo -join '; '
    throw "Skill applyTo pseudo-path check failed: $details"
}

# Exercise the production skill-visibility validator (scripts/validate-skill-visibility.ps1),
# not a test-local reimplementation, so this coverage cannot drift from real behavior.
$visibilityValidator = Join-Path $repoRoot 'scripts/validate-skill-visibility.ps1'
if (-not (Test-Path $visibilityValidator)) {
    throw "Skill visibility validator not found: $visibilityValidator"
}

# Positive: the real repository (post-normalization) must pass the production validator.
& $visibilityValidator -RootDir $repoRoot | Out-Null

# Positive/negative fixtures run through the same production validator in an isolated temp root.
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("skill-vis-" + [guid]::NewGuid().ToString('N'))
try {
    $goodDir = Join-Path $fixtureRoot 'skills/good-skill'
    $badDir = Join-Path $fixtureRoot 'skills/bad-skill'
    New-Item -ItemType Directory -Force -Path $goodDir, $badDir | Out-Null

    Set-Content -Path (Join-Path $goodDir 'SKILL.md') -Value "---`nname: good-skill`ndescription: fixture`nvisibility: public`n---`n"
    & $visibilityValidator -RootDir $fixtureRoot | Out-Null

    Set-Content -Path (Join-Path $badDir 'SKILL.md') -Value "---`nname: bad-skill`ndescription: fixture`nvisibility: `"internal`"`n---`n"
    $negativeFailed = $false
    try { & $visibilityValidator -RootDir $fixtureRoot *> $null } catch { $negativeFailed = $true }
    if (-not $negativeFailed) {
        throw "Skill visibility negative fixture failed: invalid 'internal' (agent-only tier) was accepted by the production validator"
    }
    Remove-Item -Recurse -Force $badDir

    # Body-scope regression: an invalid visibility line inside a fenced code block
    # in the BODY must NOT trip the validator, which parses only the frontmatter
    # block. A first-N-lines heuristic would false-positive here.
    $bodyDir = Join-Path $fixtureRoot 'skills/body-scope-skill'
    New-Item -ItemType Directory -Force -Path $bodyDir | Out-Null
    $bodyContent = "---`nname: body-scope-skill`ndescription: fixture`nvisibility: public`n---`n`nExample frontmatter:`n`n``````yaml`nvisibility: internal`n``````"
    Set-Content -Path (Join-Path $bodyDir 'SKILL.md') -Value $bodyContent
    & $visibilityValidator -RootDir $fixtureRoot | Out-Null
}
finally {
    if (Test-Path $fixtureRoot) { Remove-Item -Recurse -Force $fixtureRoot }
}

Write-Host "Skill compatibility frontmatter tests passed for $((Get-ChildItem -Path $skillsDir -Directory).Count) skills."
Write-Host 'Skill applyTo pseudo-path tests passed.'
Write-Host 'Skill visibility enum tests passed (production validator).'

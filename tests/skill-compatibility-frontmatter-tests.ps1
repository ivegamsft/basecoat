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

Write-Host "Skill compatibility frontmatter tests passed for $((Get-ChildItem -Path $skillsDir -Directory).Count) skills."
Write-Host 'Skill applyTo pseudo-path tests passed.'

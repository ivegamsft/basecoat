$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$skillsDir = Join-Path $repoRoot 'skills'

if (-not (Test-Path $skillsDir)) {
    throw "Skills directory not found: $skillsDir"
}

$missing = @()

Get-ChildItem -Path $skillsDir -Directory | Sort-Object Name | ForEach-Object {
    $skillName = $_.Name
    $skillFile = Join-Path $_.FullName 'SKILL.md'

    if (-not (Test-Path $skillFile)) {
        $missing += "$skillName (missing SKILL.md)"
        return
    }

    $content = Get-Content -Path $skillFile -Raw
    $frontmatter = ''
    if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        $frontmatter = $Matches[1]
    }

    if ([string]::IsNullOrWhiteSpace($frontmatter)) {
        $missing += "$skillName (missing frontmatter block)"
        return
    }

    if ($frontmatter -notmatch '(?m)^compatibility\s*:\s*\S') {
        $missing += "$skillName (missing compatibility frontmatter)"
    }
}

if ($missing.Count -gt 0) {
    $details = $missing -join '; '
    throw "Skill compatibility frontmatter check failed: $details"
}

Write-Host "Skill compatibility frontmatter tests passed for $((Get-ChildItem -Path $skillsDir -Directory).Count) skills."

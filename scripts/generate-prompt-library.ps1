#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$OutputPath = 'docs/reference/prompt-library.md',
    [string]$IntentPath = 'instructions/basecoat-10-core-intent-routing.instructions.md',
    [string]$SkillsPath = 'skills',
    [string]$AgentsPath = 'agents',
    [string]$SourceBaseUrl = 'https://github.com/IBuySpy-Shared/basecoat/blob/main'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Get-FrontmatterField {
    param(
        [string]$Content,
        [string]$Field
    )

    if ($Content -notmatch '(?s)^---\r?\n(?<frontmatter>.*?)\r?\n---') {
        return ''
    }

    $frontmatter = $Matches.frontmatter
    $lines = $frontmatter -split '\r?\n'
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch "^$([regex]::Escape($Field)):\s*(?<value>.*)$") {
            continue
        }

        $value = $Matches.value.Trim()
        if ($value -notmatch '^(?<style>[>|])(?<chomp>[+-])?$') {
            return $value.Trim('"').Trim("'")
        }
        $style = $Matches.style

        $continuation = [System.Collections.Generic.List[string]]::new()
        for ($lineIndex = $index + 1; $lineIndex -lt $lines.Count; $lineIndex++) {
            if ($lines[$lineIndex] -match '^\s*$') {
                $continuation.Add('')
                continue
            }
            if ($lines[$lineIndex] -notmatch '^\s+(?<content>.*)$') {
                break
            }
            $continuation.Add($Matches.content.Trim())
        }

        if ($style -eq '>') {
            return ($continuation -join ' ').Trim()
        }

        return ($continuation -join "`n").Trim()
    }

    return ''
}

function Get-FirstPromptCase {
    param([string]$Value)

    $depth = 0
    for ($index = 0; $index -lt $Value.Length; $index++) {
        switch ($Value[$index]) {
            { $_ -in @('(', '[', '{') } { $depth++; continue }
            { $_ -in @(')', ']', '}') } { if ($depth -gt 0) { $depth-- }; continue }
            { $_ -in @(',', ';') -and $depth -eq 0 } { return $Value.Substring(0, $index) }
        }
    }

    return $Value
}

function Get-PromptSeed {
    param([string]$Description)

    $Description = ($Description -replace '\s+', ' ').Trim()
    $seed = $Description
    if ($Description -match '(?i)USE FOR:\s*(?<useFor>.*?)(?:\s+DO NOT USE FOR:|$)') {
        $seed = Get-FirstPromptCase -Value $Matches.useFor
    }
    elseif ($Description -match '(?i)^Use when\s+(?<useWhen>.+?)(?:\.|$)') {
        $seed = $Matches.useWhen
    }
    elseif ($Description -match '(?i)^(?<summary>.*?)(?:\s+DO NOT USE FOR:|$)') {
        $seed = $Matches.summary
    }

    $seed = ($seed -replace '\s+', ' ').Trim().TrimEnd('.', ':')
    $seed = $seed -replace '(?i)^you need\s+', ''
    return $seed
}

function Get-AgentInvocationName {
    param([string]$Name)

    if ($Name -match '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        return $Name
    }

    return ($Name.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
}

function ConvertTo-TableText {
    param([string]$Value)

    return $Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('|', '&#124;')
}

$intentContent = Get-Content -Path $IntentPath -Raw
$intents = foreach ($line in $intentContent -split '\r?\n') {
    if ($line -match '^\|\s*`(?<prefix>[a-z0-9-]+:)`\s*\|\s*(?<intent>[^|]+?)\s*\|') {
        [PSCustomObject]@{
            Prefix = $Matches.prefix
            Intent = $Matches.intent.Trim()
        }
    }
}

$skills = foreach ($file in Get-ChildItem -Path $SkillsPath -Recurse -Filter 'SKILL.md' -File | Sort-Object FullName) {
    $content = Get-Content -Path $file.FullName -Raw
    $name = Get-FrontmatterField -Content $content -Field 'name'
    $description = Get-FrontmatterField -Content $content -Field 'description'
    $relativePath = $file.FullName.Substring($repoRoot.Path.Length + 1).Replace('\', '/')

    [PSCustomObject]@{
        Name = if ($name) { $name } else { $file.Directory.Name }
        Prompt = "Use the '$($name)' skill. Task: $(Get-PromptSeed -Description $description)."
        Path = $relativePath
    }
}

$agents = foreach ($file in Get-ChildItem -Path $AgentsPath -Filter '*.agent.md' -File | Sort-Object Name) {
    $content = Get-Content -Path $file.FullName -Raw
    $name = Get-FrontmatterField -Content $content -Field 'name'
    $description = Get-FrontmatterField -Content $content -Field 'description'
    $relativePath = $file.FullName.Substring($repoRoot.Path.Length + 1).Replace('\', '/')

    [PSCustomObject]@{
        Name = if ($name) { $name } else { $file.BaseName -replace '\.agent$', '' }
        Prompt = "@$(Get-AgentInvocationName -Name $name) Help me with this task: $(Get-PromptSeed -Description $description)."
        Path = $relativePath
    }
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# BaseCoat Sample Prompt Library')
$lines.Add('')
$lines.Add('Generated from the canonical intent vocabulary and asset frontmatter. Do not edit the generated tables directly; run `pwsh scripts/generate-prompt-library.ps1`.')
$lines.Add('')
$lines.Add("Coverage: $($intents.Count) intents, $($skills.Count) skills, and $($agents.Count) agents.")
$lines.Add('')
$lines.Add('## Lifecycle prompts')
$lines.Add('')
$lines.Add('### Onboard BaseCoat')
$lines.Add('')
$lines.Add('```text')
$lines.Add('feature: onboard this repository to BaseCoat using a pinned release. Start with a dry run, preserve repository-owned files, validate installed assets, and open a reviewable pull request.')
$lines.Add('```')
$lines.Add('')
$lines.Add('### Refresh BaseCoat')
$lines.Add('')
$lines.Add('```text')
$lines.Add('chore: refresh this repository to BaseCoat vX.Y.Z using its .basecoat.yml policy. Show the drift first, apply only managed-file changes, run validation, and open a pull request.')
$lines.Add('```')
$lines.Add('')
$lines.Add('### Remove BaseCoat')
$lines.Add('')
$lines.Add('```text')
$lines.Add('chore: remove BaseCoat-managed assets from this repository. Use the manifest and sync state to identify managed files, preserve repository-owned customizations, show a dry-run removal plan, and require approval before deletion.')
$lines.Add('```')
$lines.Add('')
$lines.Add('## Sample outputs')
$lines.Add('')
$lines.Add('These examples show the expected shape, not live repository results.')
$lines.Add('')
$lines.Add('### Onboarding output example')
$lines.Add('')
$lines.Add('```text')
$lines.Add('Onboarding mode: dry-run')
$lines.Add('Pinned release: vX.Y.Z')
$lines.Add('Managed target: .github/base-coat/')
$lines.Add('Validation: pending')
$lines.Add('Next action: review the proposed file plan before sync')
$lines.Add('```')
$lines.Add('')
$lines.Add('### Refresh output example')
$lines.Add('')
$lines.Add('```text')
$lines.Add('Current version: vX.Y.A')
$lines.Add('Target version: vX.Y.Z')
$lines.Add('Managed files changed: 12')
$lines.Add('Repository-owned conflicts: 0')
$lines.Add('Next action: run validation and open the refresh PR')
$lines.Add('```')
$lines.Add('')
$lines.Add('### Removal output example')
$lines.Add('')
$lines.Add('```text')
$lines.Add('Managed files eligible for removal: 24')
$lines.Add('Repository-owned files preserved: 7')
$lines.Add('Approval required: yes')
$lines.Add('Next action: approve the exact removal list')
$lines.Add('```')
$lines.Add('')
$lines.Add('### YAGNI analysis output example')
$lines.Add('')
$lines.Add('```text')
$lines.Add('Candidate: package-x')
$lines.Add('Usage: dynamic')
$lines.Add('Evidence for use: runtime plugin configuration is unresolved')
$lines.Add('Evidence against use: no direct source import found')
$lines.Add('Confidence: low - dynamic loading has not been observed')
$lines.Add('Decision: instrument')
$lines.Add('Validation: capture plugin-load telemetry before removal')
$lines.Add('Rollback: disable the experiment and retain the package')
$lines.Add('Mutation performed: none')
$lines.Add('```')
$lines.Add('')
$lines.Add('### Backlog revalidation output example')
$lines.Add('')
$lines.Add('```text')
$lines.Add('Item: issue #1234')
$lines.Add('Mode: single')
$lines.Add('Age filter only: yes')
$lines.Add('Classification: superseded')
$lines.Add('Confidence: high - merged PR #567 implemented the same outcome')
$lines.Add('Citations: PR #567, src/example.ts:40, v4.2.1 release notes')
$lines.Add('Canonical: https://github.com/example/repo/issues/2000')
$lines.Add('Recommended action: close')
$lines.Add('Mutation performed: none')
$lines.Add('```')
$lines.Add('')
$lines.Add('## Intent prompts')
$lines.Add('')
$lines.Add('<!-- markdownlint-disable MD033 -->')
$lines.Add('')
$lines.Add('| Intent | Sample prompt |')
$lines.Add('|---|---|')
foreach ($intent in $intents) {
    $prompt = "$($intent.Prefix) $($intent.Intent) in this repository. Include scope, evidence, and the next safe action."
    $lines.Add("| ``$($intent.Prefix)`` | <code>$(ConvertTo-TableText -Value $prompt)</code> |")
}

$lines.Add('')
$lines.Add('## Skill prompts')
$lines.Add('')
$lines.Add('| Skill | Sample prompt | Source |')
$lines.Add('|---|---|---|')
foreach ($skill in $skills) {
    $lines.Add("| ``$(ConvertTo-TableText -Value $skill.Name)`` | <code>$(ConvertTo-TableText -Value $skill.Prompt)</code> | [$($skill.Path)]($SourceBaseUrl/$($skill.Path)) |")
}

$lines.Add('')
$lines.Add('## Agent prompts')
$lines.Add('')
$lines.Add('| Agent | Sample prompt | Source |')
$lines.Add('|---|---|---|')
foreach ($agent in $agents) {
    $lines.Add("| ``$(ConvertTo-TableText -Value $agent.Name)`` | <code>$(ConvertTo-TableText -Value $agent.Prompt)</code> | [$($agent.Path)]($SourceBaseUrl/$($agent.Path)) |")
}
$lines.Add('')
$lines.Add('<!-- markdownlint-enable MD033 -->')

$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
}
else {
    Join-Path $repoRoot $OutputPath
}

$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$content = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText($resolvedOutput, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host "Generated $resolvedOutput with $($intents.Count) intents, $($skills.Count) skills, and $($agents.Count) agents"

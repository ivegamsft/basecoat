[CmdletBinding()]
param(
    [string]$RootDir = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = (Resolve-Path -LiteralPath $RootDir).Path
. (Join-Path $PSScriptRoot 'model-policy-contract.ps1')

function Get-FrontmatterScalar {
    param(
        [string]$Frontmatter,
        [string]$Name
    )

    $match = [regex]::Match($Frontmatter, "(?m)^$([regex]::Escape($Name)):\s*(?<value>[^#\r\n]*?)\s*(?:#.*)?$")
    if (-not $match.Success) {
        return ''
    }

    return $match.Groups['value'].Value.Trim().Trim('"').Trim("'")
}

function Get-PreferredFamilyValues {
    param([string]$Frontmatter)

    $lines = $Frontmatter -split "\r?\n"
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch '^\s{2}preferred_families:\s*(?<value>.*)$') {
            continue
        }

        $value = $matches['value'].Trim()
        if ($value.StartsWith('[')) {
            if ($value -notmatch '^\[(?<items>.*)\]\s*(?:#.*)?$') {
                throw 'preferred_families inline list is malformed.'
            }
            $items = $matches['items']
            if ([string]::IsNullOrWhiteSpace($items)) {
                return @()
            }
            return @(
                $items -split ',' | ForEach-Object {
                    $_.Trim().Trim('"').Trim("'")
                }
            )
        }

        $values = @()
        for ($itemIndex = $index + 1; $itemIndex -lt $lines.Count; $itemIndex++) {
            if ($lines[$itemIndex] -match '^\s{4,}-\s*(?<item>[^#\r\n]+?)\s*(?:#.*)?$') {
                $values += $matches['item'].Trim().Trim('"').Trim("'")
                continue
            }
            if ([string]::IsNullOrWhiteSpace($lines[$itemIndex])) {
                continue
            }
            break
        }

        if ($values.Count -eq 0) {
            throw 'preferred_families must be a non-empty inline or block list.'
        }
        return $values
    }

    return @()
}

$failures = @()
$assetFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $resolvedRoot 'agents') -Filter '*.agent.md' -File -ErrorAction Stop
    Get-ChildItem -LiteralPath (Join-Path $resolvedRoot 'skills') -Recurse -Filter 'SKILL.md' -File -ErrorAction Stop
)

foreach ($file in $assetFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $frontmatterMatch = [regex]::Match($content, '^\x2d\x2d\x2d\r?\n(?<frontmatter>[\s\S]*?)\r?\n\x2d\x2d\x2d(?:\r?\n|$)')
    if (-not $frontmatterMatch.Success) {
        continue
    }

    $frontmatter = $frontmatterMatch.Groups['frontmatter'].Value
    $relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')

    try {
        $families = @(Get-PreferredFamilyValues -Frontmatter $frontmatter)
        if ($families.Count -gt 0) {
            $normalized = @(Resolve-PreferredModelFamilies -RequestedFamilies $families)
            for ($index = 0; $index -lt $families.Count; $index++) {
                if ($families[$index] -cne $normalized[$index]) {
                    $failures += "$($relativePath): preferred_families selector '$($families[$index])' is non-canonical; use '$($normalized[$index])'."
                }
            }
        }

        $pinnedModel = Get-FrontmatterScalar -Frontmatter $frontmatter -Name 'pinned_model'
        $pinReason = Get-FrontmatterScalar -Frontmatter $frontmatter -Name 'pin_reason'
        $model = Get-FrontmatterScalar -Frontmatter $frontmatter -Name 'model'
        $fallbackMatch = [regex]::Match($frontmatter, '(?m)^\s{2}fallback:\s*(?<value>true|false)\s*(?:#.*)?$')
        $fallback = -not ($fallbackMatch.Success -and $fallbackMatch.Groups['value'].Value -eq 'false')
        $null = Resolve-PreferredModelPolicy `
            -PinnedModel $pinnedModel `
            -PinReason $pinReason `
            -Model $model `
            -PreferredFamilies $families `
            -Fallback $fallback
    }
    catch {
        $failures += "$relativePath`: $($_.Exception.Message)"
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "ERROR: $failure" -ForegroundColor Red
    }
    throw "Model policy validation found $($failures.Count) error(s)."
}

Write-Host "Model policy validation passed for $($assetFiles.Count) agent and skill asset(s)." -ForegroundColor Green

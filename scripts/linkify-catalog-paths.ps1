#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Converts catalog table file paths into clickable markdown links.

.DESCRIPTION
    Rewrites table cells containing backticked repository paths (agents/, skills/,
    instructions/, prompts/, portal/prompts/, docs/, scripts/, .github/) so docs
    expose direct links to files.
#>

param(
    [string[]]$Paths = @(
        "docs/reference/inventory.md",
        "docs/reference/asset-registry.md",
        "docs/reference/asset-catalog.md"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot

foreach ($relativePath in $Paths) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path $fullPath)) {
        Write-Warning "Skipping missing file: $relativePath"
        continue
    }

    $content = Get-Content -Path $fullPath -Raw -Encoding UTF8

    $updated = [Regex]::Replace(
        $content,
        '\|\s*`((?:(?:agents|skills|instructions|prompts|portal/prompts|docs|scripts|\.github)/[^\s`,|]+))`\s*\|',
        {
            param($match)
            $path = $match.Groups[1].Value
            $sourceDir = Split-Path -Parent $fullPath
            $targetPath = Join-Path $repoRoot $path
            $relativeTarget = [System.IO.Path]::GetRelativePath($sourceDir, $targetPath).Replace('\', '/')
            "| [$path]($relativeTarget) |"
        }
    )

    if ($updated -ne $content) {
        Set-Content -Path $fullPath -Value $updated -Encoding UTF8 -NoNewline
        Write-Host "Updated links in $relativePath"
    } else {
        Write-Host "No link updates needed in $relativePath"
    }
}

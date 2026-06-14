#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Add category field to all agent frontmatter for governance hardening.

.DESCRIPTION
    This script systematically adds the metadata.category field to all agents
    based on their naming prefix (10-core, 20-lang, etc.).
#>

function Get-CategoryFromName {
    param([string]$agentName)
    
    if ($agentName -match "^basecoat-(\d{2})-") {
        $prefix = $matches[1]
        switch ($prefix) {
            "10" { return "core" }
            "20" { return "language" }
            "30" { return "ai" }
            "40" { return "cloud" }
            "50" { return "security" }
            "60" { return "workflow" }
            "80" { return "data" }
            "90" { return "quality" }
            default { return "uncategorized" }
        }
    }
    return "uncategorized"
}

function Add-CategoryToAgentFile {
    param(
        [string]$filePath,
        [string]$category
    )
    
    $lines = @(Get-Content $filePath)
    
    # If category already exists, skip
    $hasCategory = $lines | Where-Object { $_ -match "^\s+category:" }
    if ($hasCategory) {
        return "SKIP"
    }
    
    # Find the frontmatter closing line (second ---)
    $frontmatterEndIdx = -1
    $dashCount = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq "---") {
            $dashCount++
            if ($dashCount -eq 2) {
                $frontmatterEndIdx = $i
                break
            }
        }
    }
    
    if ($frontmatterEndIdx -eq -1) {
        return "FAIL"
    }
    
    # Check if metadata section already exists
    $metadataIdx = -1
    for ($i = 1; $i -lt $frontmatterEndIdx; $i++) {
        if ($lines[$i] -eq "metadata:") {
            $metadataIdx = $i
            break
        }
    }
    
    if ($metadataIdx -gt 0) {
        # Insert category right after metadata: line
        $lines[$metadataIdx] += "`n  category: $category"
    } else {
        # Insert metadata section before the closing ---
        $metadataBlock = @(
            "metadata:",
            "  category: $category",
            "  maturity: alpha",
            "  audience:",
            "    - developer"
        )
        
        # Insert before the closing ---
        $newLines = @()
        for ($i = 0; $i -lt $frontmatterEndIdx; $i++) {
            $newLines += $lines[$i]
        }
        $newLines += $metadataBlock
        $newLines += $lines[$frontmatterEndIdx..($lines.Count - 1)]
        $lines = $newLines
    }
    
    Set-Content $filePath $lines -Encoding UTF8
    return "OK"
}

# Process all agents
$agents = @(Get-ChildItem agents/*.agent.md)
$results = @{OK = 0; SKIP = 0; NO_META = 0; FAIL = 0}

Write-Host "Processing $($agents.Count) agents..."

foreach ($agent in $agents) {
    $name = $agent.BaseName
    $category = Get-CategoryFromName $name
    $status = Add-CategoryToAgentFile $agent.FullName $category
    $results[$status]++
    
    if ($status -ne "OK" -and $status -ne "SKIP") {
        Write-Host "  [W] $($name): $status"
    }
}

Write-Host "`nResults:"
foreach ($key in @("OK", "SKIP", "NO_META", "FAIL")) {
    Write-Host "  $($key): $($results[$key])"
}

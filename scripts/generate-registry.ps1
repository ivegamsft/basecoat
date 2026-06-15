#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates basecoat-registry.json from agents/*.agent.md frontmatter.

.DESCRIPTION
    Reads all agent files, extracts YAML frontmatter fields (name, description,
    metadata, and model hints), resolves model hints through an allowlisted
    default policy, and writes a registry JSON file consumable by the
    copilot-cli-plugin without exposing org-level model configuration.

.EXAMPLE
    pwsh scripts/generate-registry.ps1
    pwsh scripts/generate-registry.ps1 -OutputPath plugins/copilot-cli-plugin/schema/basecoat-registry.json
#>

param(
    [string]$AgentsPath = (Join-Path $PSScriptRoot ".." "agents"),
    [string]$OutputPath = (Join-Path $PSScriptRoot ".." "plugins" "copilot-cli-plugin" "schema" "basecoat-registry.json"),
    [string[]]$AllowedModels = @("claude-sonnet-4.6", "claude-sonnet-4.5", "claude-haiku-4.5", "gpt-5.3-codex", "gpt-5.4-mini"),
    [string]$DefaultModel = "claude-sonnet-4.6",
    [string[]]$DisabledModels = @()
)

$ErrorActionPreference = "Stop"

function Get-CanonicalModelId {
    param([string]$ModelId)

    if ([string]::IsNullOrWhiteSpace($ModelId)) { return "" }

    $normalized = $ModelId.Trim().Trim('"').Trim("'").ToLowerInvariant()
    $normalized = $normalized -replace '[ _]+', '-'
    $normalized = $normalized -replace '-+', '-'

    $aliasMap = @{
        "claude-sonnet-4-6" = "claude-sonnet-4.6"
        "claude-sonnet-4-5" = "claude-sonnet-4.5"
        "claude-haiku-4-5" = "claude-haiku-4.5"
        "claude-opus-4-8" = "claude-opus-4.8"
        "claude-opus-4-7" = "claude-opus-4.7"
        "claude-opus-4-6" = "claude-opus-4.6"
        "claude-opus-4-5" = "claude-opus-4.5"
        "gpt-5-5" = "gpt-5.5"
        "gpt-5-4" = "gpt-5.4"
        "gpt-5-4-mini" = "gpt-5.4-mini"
        "gpt-5-3-codex" = "gpt-5.3-codex"
        "gpt-5-mini" = "gpt-5-mini"
        "gemini-3-1-pro-preview" = "gemini-3.1-pro-preview"
        "gemini-3-5-flash" = "gemini-3.5-flash"
    }

    if ($aliasMap.ContainsKey($normalized)) {
        return $aliasMap[$normalized]
    }

    return $normalized
}

function Get-ModelHintFromFrontmatter {
    param([string]$Frontmatter)

    if ($Frontmatter -match '(?m)^pinned_model:\s*(.+)$') { return $Matches[1].Trim().Trim('"').Trim("'") }
    if ($Frontmatter -match '(?m)^model:\s*(.+)$') { return $Matches[1].Trim().Trim('"').Trim("'") }
    return ""
}

function Resolve-RegistryModel {
    param(
        [string]$Frontmatter,
        [System.Collections.Generic.HashSet[string]]$AllowedModelSet,
        [System.Collections.Generic.HashSet[string]]$DisabledModelSet,
        [string]$FallbackModel
    )

    $modelHint = Get-ModelHintFromFrontmatter -Frontmatter $Frontmatter
    if ([string]::IsNullOrWhiteSpace($modelHint)) { return $FallbackModel }

    $canonicalHint = Get-CanonicalModelId -ModelId $modelHint
    if ([string]::IsNullOrWhiteSpace($canonicalHint)) { return $FallbackModel }
    if ($DisabledModelSet.Contains($canonicalHint)) { return $FallbackModel }
    if (-not $AllowedModelSet.Contains($canonicalHint)) { return $FallbackModel }
    return $canonicalHint
}

$allowedCanonical = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($allowedModel in $AllowedModels) {
    $canonicalAllowed = Get-CanonicalModelId -ModelId $allowedModel
    if (-not [string]::IsNullOrWhiteSpace($canonicalAllowed)) {
        [void]$allowedCanonical.Add($canonicalAllowed)
    }
}

if ($allowedCanonical.Count -eq 0) {
    throw "Allowed model list is empty after canonicalization."
}

$defaultCanonical = Get-CanonicalModelId -ModelId $DefaultModel
if ([string]::IsNullOrWhiteSpace($defaultCanonical)) {
    throw "Default model '$DefaultModel' could not be canonicalized."
}
if (-not $allowedCanonical.Contains($defaultCanonical)) {
    throw "Default model '$defaultCanonical' must exist in AllowedModels."
}

$disabledCanonical = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($disabledModel in $DisabledModels) {
    $canonicalDisabled = Get-CanonicalModelId -ModelId $disabledModel
    if (-not [string]::IsNullOrWhiteSpace($canonicalDisabled)) {
        [void]$disabledCanonical.Add($canonicalDisabled)
    }
}

$agentsDir = $AgentsPath
$agents = @{}

Get-ChildItem $agentsDir -Filter "*.agent.md" | ForEach-Object {
    $file = $_.FullName
    $content = Get-Content $file -Raw
    $relativePath = "agents/$($_.Name)"

    # Extract YAML frontmatter
    if ($content -match "^---\s*\n([\s\S]+?)\n---") {
        $frontmatter = $Matches[1]

        $id = $_.Name -replace "\.agent\.md$", ""
        # Extract short agent name from new naming convention
        $id = $id -replace '^basecoat-\d+-\w+-', ''
        $name = if ($frontmatter -match "^name:\s*(.+)$") { $Matches[1].Trim().Trim('"') } else { $id }
        $description = if ($frontmatter -match "^description:\s*(.+)$") { $Matches[1].Trim().Trim('"') } else { "No description" }
        $model = Resolve-RegistryModel -Frontmatter $frontmatter -AllowedModelSet $allowedCanonical -DisabledModelSet $disabledCanonical -FallbackModel $defaultCanonical
        $maturity = if ($frontmatter -match "maturity:\s*[""']?(\w+)[""']?") { $Matches[1].Trim() } else { "production" }
        $category = if ($frontmatter -match "category:\s*[""']?([^""'\n]+)[""']?") { $Matches[1].Trim() } else { "General" }

        # Extract tags as keywords
        $keywords = @($id -split "-")
        if ($frontmatter -match "tags:\s*\[([^\]]+)\]") {
            $tagStr = $Matches[1]
            $keywords += $tagStr -split "," | ForEach-Object { $_.Trim().Trim('"').Trim("'") }
        }
        $keywords = $keywords | Where-Object { $_ -ne "" } | Select-Object -Unique

        # Capabilities from tags or category
        $capabilities = @()
        if ($category -match "backend|api|data") { $capabilities += "backend" }
        if ($category -match "frontend|ui|ux") { $capabilities += "frontend" }
        if ($category -match "security|compliance") { $capabilities += "security" }
        if ($category -match "infra|azure|kubernetes|cloud") { $capabilities += "infrastructure" }
        if ($category -match "test|qa|quality") { $capabilities += "testing" }
        if ($category -match "project|planning|management") { $capabilities += "planning" }
        if ($capabilities.Count -eq 0) { $capabilities = @("general") }

        $agents[$id] = [ordered]@{
            id           = $id
            name         = $name
            description  = $description.Substring(0, [Math]::Min(120, $description.Length))
            file         = $relativePath
            keywords     = @($keywords | Select-Object -First 15)
            capabilities = @($capabilities)
            model        = $model
            maturity     = $maturity
            category     = $category
        }
    }
}

$registry = [ordered]@{
    version   = "1.0.0"
    generated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    agents    = $agents
}

$json = $registry | ConvertTo-Json -Depth 10
Set-Content $OutputPath $json -Encoding UTF8

Write-Host "Registry written: $OutputPath"
Write-Host "Agents indexed: $($agents.Count)"

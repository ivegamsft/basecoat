#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates basecoat-registry.json from agents/*.agent.md frontmatter.

.DESCRIPTION
    Reads all agent files, extracts YAML frontmatter fields (name, description,
    metadata, model), and writes a registry JSON file consumable by the
    copilot-cli-plugin.

.EXAMPLE
    pwsh scripts/generate-registry.ps1
    pwsh scripts/generate-registry.ps1 -OutputPath plugins/copilot-cli-plugin/schema/basecoat-registry.json
#>

param(
    [string]$OutputPath = (Join-Path $PSScriptRoot ".." "plugins" "copilot-cli-plugin" "schema" "basecoat-registry.json"),
    [string]$AgentsPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "agents")
)

$agents = @{}
$allowedModels = @(
    'gpt-5.4-mini',
    'gpt-5.3-codex',
    'claude-sonnet-4.5',
    'claude-haiku-4.5'
)
$fallbackModel = 'gpt-5.4-mini'
$fallbackMap = @{
    'claude-sonnet-4.6' = 'claude-sonnet-4.5'
    'claude-sonnet-4.7' = 'claude-sonnet-4.5'
    'claude-opus-4.6'   = 'claude-sonnet-4.5'
    'claude-opus-4.7'   = 'claude-sonnet-4.5'
    'claude-opus-4.8'   = 'claude-sonnet-4.5'
    'gpt-5.5'           = 'gpt-5.3-codex'
    'gpt-5.4'           = 'gpt-5.3-codex'
}
$modelSubstitutions = New-Object System.Collections.Generic.List[string]

function Resolve-AgentModel {
    param([string]$RequestedModel)

    $trimmed = ($RequestedModel ?? '').Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $fallbackModel
    }

    if ($allowedModels -contains $trimmed) {
        return $trimmed
    }

    if ($fallbackMap.ContainsKey($trimmed) -and $allowedModels -contains $fallbackMap[$trimmed]) {
        return $fallbackMap[$trimmed]
    }

    return $fallbackModel
}

Get-ChildItem $AgentsPath -Filter "*.agent.md" | ForEach-Object {
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
        $requestedModel = if ($frontmatter -match "(?m)^model:\s*(.+)$") { $Matches[1].Trim() } else { $fallbackModel }
        $model = Resolve-AgentModel -RequestedModel $requestedModel
        if ($requestedModel.Trim('"').Trim("'") -ne $model) {
            $modelSubstitutions.Add("${id}: $requestedModel -> $model") | Out-Null
        }
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
if ($modelSubstitutions.Count -gt 0) {
    Write-Host "Model substitutions applied: $($modelSubstitutions.Count)"
    $modelSubstitutions | ForEach-Object { Write-Host "  - $_" }
}

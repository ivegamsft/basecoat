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
$policyScriptPath = Join-Path $PSScriptRoot 'model-fallback-policy.ps1'
if (-not (Test-Path -LiteralPath $policyScriptPath)) {
    throw "Model fallback policy script not found: $policyScriptPath"
}
. $policyScriptPath

$fallbackModel = Get-DefaultFrontmatterModel
$modelSubstitutions = New-Object System.Collections.Generic.List[string]

function Get-FrontmatterScalarValue {
    <#
    .SYNOPSIS
        Extracts a top-level frontmatter scalar value for $KeyName, folding
        YAML block scalars (`>` folded, `|` literal, with optional chomping
        indicators `-` (strip) / `+` (keep), default (clip)) into a single
        value instead of returning the bare block-scalar indicator
        character, while preserving relative indentation within the block
        and honoring chomping semantics.
    #>
    param(
        [string[]]$Lines,
        [string]$KeyName
    )

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -notmatch "^${KeyName}:\s*(.*)$") { continue }

        $inlineValue = $Matches[1].Trim()

        if ($inlineValue -match '^([>|])([+-]?)\s*$') {
            $isFolded = $Matches[1] -eq '>'
            $chomp = $Matches[2]
            $rawLines = New-Object System.Collections.Generic.List[string]
            $baseIndent = $null
            for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
                $candidate = $Lines[$j]
                if ($candidate.Trim() -eq '') {
                    # Blank lines are valid inside block scalars (paragraph
                    # breaks for folded scalars); keep scanning instead of
                    # stopping here.
                    $rawLines.Add('')
                    continue
                }
                if ($candidate -notmatch '^(\s+)\S') { break }
                $indent = $Matches[1].Length
                if ($null -eq $baseIndent) { $baseIndent = $indent }
                elseif ($indent -lt $baseIndent) { break }
                $rawLines.Add($candidate)
            }
            if ($null -eq $baseIndent) {
                return ''
            }

            # Dedent by exactly the block's base indentation, preserving any
            # additional relative indentation within each line. A blanket
            # per-line Trim() (as before) would destroy meaningful literal
            # indentation (e.g. nested lists inside a `|` description).
            $dedented = @($rawLines | ForEach-Object {
                if ($_ -eq '') { '' } else { $_.Substring([Math]::Min($baseIndent, $_.Length)) }
            })

            # Chomping indicator controls trailing-newline handling:
            #   (none) = clip  -> trailing blanks removed, single trailing newline kept
            #   '-'    = strip -> trailing blanks removed, no trailing newline
            #   '+'    = keep  -> trailing blank lines preserved as-is
            $trailingBlankCount = 0
            for ($k = $dedented.Count - 1; $k -ge 0; $k--) {
                if ($dedented[$k] -eq '') { $trailingBlankCount++ } else { break }
            }
            $contentLines = if ($trailingBlankCount -gt 0) {
                @($dedented | Select-Object -First ($dedented.Count - $trailingBlankCount))
            } else {
                $dedented
            }
            if ($contentLines.Count -eq 0) {
                return ''
            }

            if (-not $isFolded) {
                $body = ($contentLines -join "`n")
            } else {
                # Folded (`>`) scalars per YAML fold rules: a single line
                # break between two content lines folds to a space, while N
                # (N>=1) consecutive blank lines between content lines fold
                # to exactly N newline characters (not collapsed to a fixed
                # paragraph separator) so the exact blank-line count of the
                # source is reproduced in the folded value.
                $sb = New-Object System.Text.StringBuilder
                $pendingBlankLines = 0
                $hasContent = $false
                foreach ($line in $contentLines) {
                    $trimmedLine = $line.Trim()
                    if ($trimmedLine -eq '') {
                        $pendingBlankLines++
                        continue
                    }
                    if ($hasContent) {
                        if ($pendingBlankLines -gt 0) {
                            [void]$sb.Append(("`n" * $pendingBlankLines))
                        } else {
                            [void]$sb.Append(' ')
                        }
                    }
                    [void]$sb.Append($trimmedLine)
                    $hasContent = $true
                    $pendingBlankLines = 0
                }
                $body = $sb.ToString()
            }

            switch ($chomp) {
                '-' { return $body }
                '+' { return $body + ("`n" * ($trailingBlankCount + 1)) }
                default { return "$body`n" }
            }
        }

        return $inlineValue.Trim('"').Trim("'")
    }

    return $null
}

Get-ChildItem $AgentsPath -Filter "*.agent.md" | ForEach-Object {
    $file = $_.FullName
    $content = Get-Content $file -Raw
    $relativePath = "agents/$($_.Name)"

    # Extract YAML frontmatter
    if ($content -match "^---\s*\n([\s\S]+?)\n---") {
        $frontmatter = $Matches[1]
        $frontmatterLines = $frontmatter -split "`r?`n"

        $id = $_.Name -replace "\.agent\.md$", ""
        # Extract short agent name from new naming convention
        $id = $id -replace '^basecoat-\d+-\w+-', ''
        $name = Get-FrontmatterScalarValue -Lines $frontmatterLines -KeyName 'name'
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $id }
        $description = Get-FrontmatterScalarValue -Lines $frontmatterLines -KeyName 'description'
        if ([string]::IsNullOrWhiteSpace($description)) { $description = "No description" }
        $requestedModel = if ($frontmatter -match "(?m)^model:\s*(.+)$") { $Matches[1].Trim() } else { $fallbackModel }
        $model = (Resolve-FrontmatterModel -RequestedModel $requestedModel -Context "generate-registry:$id").Model
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
            description  = $description
            file         = $relativePath
            keywords     = @($keywords | Select-Object -First 15)
            capabilities = @($capabilities)
            model        = $model
            maturity     = $maturity
            category     = $category
        }
    }
}

$orderedAgents = [ordered]@{}
foreach ($agentId in ($agents.Keys | Sort-Object)) {
    $orderedAgents[$agentId] = $agents[$agentId]
}

$registry = [ordered]@{
    version   = "1.0.0"
    generated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    agents    = $orderedAgents
}

$json = $registry | ConvertTo-Json -Depth 10
Set-Content $OutputPath $json -Encoding UTF8

Write-Host "Registry written: $OutputPath"
Write-Host "Agents indexed: $($agents.Count)"
if ($modelSubstitutions.Count -gt 0) {
    Write-Host "Model substitutions applied: $($modelSubstitutions.Count)"
    $modelSubstitutions | ForEach-Object { Write-Host "  - $_" }
}

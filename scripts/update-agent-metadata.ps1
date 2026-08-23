#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deterministically updates agent `model:` frontmatter values.

.DESCRIPTION
    Applies tier-based model defaults to current agent frontmatter without relying on
    legacy insertion anchors. This script only updates the supported top-level `model:`
    key and does not mutate unrelated metadata blocks.
#>

param(
    [string]$AgentsPath = (Join-Path $PSScriptRoot ".." "agents"),
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$policyScriptPath = Join-Path $PSScriptRoot 'model-fallback-policy.ps1'
if (-not (Test-Path $policyScriptPath)) {
    throw "Model fallback policy script not found: $policyScriptPath"
}
. $policyScriptPath

$tierByAgent = @{
    "agent-designer" = "balanced"; "agentops" = "balanced"; "api-designer" = "reasoning"; "api-security" = "reasoning"
    "app-inventory" = "balanced"; "azure-landing-zone" = "reasoning"; "backend-dev" = "balanced"; "chaos-engineer" = "balanced"
    "code-review" = "balanced"; "config-auditor" = "fast"; "container-security" = "balanced"; "containerization-planner" = "reasoning"
    "contract-testing" = "balanced"; "data-architect" = "reasoning"; "data-integrity" = "balanced"; "data-pipeline" = "balanced"
    "data-tier" = "balanced"; "database-migration" = "balanced"; "dataops" = "balanced"; "dependency-lifecycle" = "fast"
    "dependency-update-advisor" = "balanced"; "devops-engineer" = "balanced"; "domain-designer" = "reasoning"; "dotnet-modernization-advisor" = "reasoning"
    "e2e-test-strategy" = "balanced"; "exploratory-charter" = "balanced"; "feedback-loop" = "fast"; "finops-advisor" = "balanced"
    "frontend-dev" = "balanced"; "github-security-posture" = "balanced"; "gitops-engineer" = "balanced"; "guardrail" = "fast"
    "guidance-author" = "balanced"; "guidance-reviewer" = "balanced"; "ha-architect" = "reasoning"; "hardening-advisor" = "reasoning"
    "identity-architect" = "reasoning"; "incident-responder" = "reasoning"; "infrastructure-deploy" = "balanced"; "issue-triage" = "fast"
    "legacy-modernization" = "reasoning"; "llmops" = "balanced"; "manual-test-strategy" = "balanced"; "mcp-developer" = "balanced"
    "memory-curator" = "fast"; "memory-promoter" = "fast"; "merge-coordinator" = "fast"; "middleware-dev" = "balanced"
    "mlops" = "balanced"; "new-customization" = "fast"; "observability-engineer" = "balanced"; "penetration-test" = "reasoning"
    "performance-analyst" = "balanced"; "policy-as-code-compliance" = "reasoning"; "product-manager" = "reasoning"; "production-readiness" = "balanced"
    "project-onboarding" = "balanced"; "prompt-coach" = "balanced"; "prompt-engineer" = "balanced"; "release-impact-advisor" = "balanced"
    "release-manager" = "balanced"; "resilience-reviewer" = "balanced"; "retro-facilitator" = "balanced"; "rollout-basecoat" = "balanced"
    "secrets-manager" = "balanced"; "security-analyst" = "reasoning"; "security-monitor" = "balanced"; "security-operations" = "balanced"
    "self-healing-ci" = "fast"; "solution-architect" = "reasoning"; "sprint-planner" = "balanced"; "sprint-retrospective" = "balanced"
    "sre-engineer" = "balanced"; "strategy-to-automation" = "reasoning"; "supply-chain-security" = "reasoning"; "tech-writer" = "balanced"
    "ux-designer" = "balanced"; "agentic-sdlc-autonomy" = "reasoning"; "dependabot-prioritizer" = "fast"
    "instruction-auditor" = "fast"; "project-rules-drift-auditor" = "reasoning"; "backlog-autopilot" = "balanced"
    "ci-guardrail-accelerator" = "fast"; "incident-to-backlog-router" = "balanced"; "parallel-session-coordinator" = "balanced"
    "orchestrator" = "fast"; "basecoat-10-core-orchestrator" = "balanced"
}

# Agents that require a specific model not covered by tier defaults.
# Values are resolved through Resolve-FrontmatterModel (aliases apply).
$exactModelByAgent = @{
    "parallel-session-coordinator" = "claude-sonnet-4.6"
    "basecoat-10-core-orchestrator" = "claude-sonnet-4.6"
}

function Get-AgentNameFromFile {
    param(
        [string]$FileName,
        [hashtable]$TierByAgent
    )
    $base = $FileName -replace '\.agent\.md$', ''

    # If the un-stripped filename is itself a recognized key, prefer it. This avoids
    # collisions such as "basecoat-10-core-orchestrator" and "orchestrator" both
    # collapsing to the same stripped name "orchestrator" and sharing one tier/model.
    if ($TierByAgent -and $TierByAgent.ContainsKey($base)) {
        return $base
    }

    return ($base -replace '^basecoat-\d+-[^-]+-', '')
}

function Set-ModelInFrontmatter {
    param(
        [string]$Content,
        [string]$Model
    )

    $match = [Regex]::Match($Content, '(?s)^---\s*\r?\n(.*?)\r?\n---')
    if (-not $match.Success) {
        return $Content
    }

    $frontmatter = $match.Groups[1].Value
    $updatedFrontmatter = $frontmatter

    if ($updatedFrontmatter -match '(?m)^model:\s*.+$') {
        $updatedFrontmatter = [Regex]::Replace($updatedFrontmatter, '(?m)^model:\s*.+$', "model: $Model")
    } else {
        if ($updatedFrontmatter -match '(?m)^visibility:\s*.+$') {
            $updatedFrontmatter = [Regex]::Replace(
                $updatedFrontmatter,
                '(?m)^(visibility:\s*.+)$',
                "`$1`r`nmodel: $Model"
            )
        } else {
            $updatedFrontmatter = "$updatedFrontmatter`r`nmodel: $Model"
        }
    }

    $prefix = $Content.Substring(0, $match.Groups[1].Index)
    $suffix = $Content.Substring($match.Groups[1].Index + $match.Groups[1].Length)
    return "$prefix$updatedFrontmatter$suffix"
}

$updated = 0
$skipped = 0

Get-ChildItem -Path $AgentsPath -Filter "*.agent.md" -File | Sort-Object Name | ForEach-Object {
    $agentName = Get-AgentNameFromFile -FileName $_.Name -TierByAgent $tierByAgent
    if (-not $tierByAgent.ContainsKey($agentName)) {
        $skipped++
        Write-Warning "Skipping $($_.Name): no tier mapping for '$agentName'"
        return
    }

    $tier = $tierByAgent[$agentName]
    if ($exactModelByAgent.ContainsKey($agentName)) {
        $resolved = Resolve-FrontmatterModel -RequestedModel $exactModelByAgent[$agentName] -Tier $tier -Context $agentName
    } else {
        $resolved = Resolve-FrontmatterModel -RequestedModel (Get-TierDefaultFrontmatterModel -Tier $tier) -Tier $tier -Context $agentName
    }
    $targetModel = $resolved.Model
    if ($resolved.Substituted) {
        Write-Warning "[$agentName] $($resolved.Reason): '$($resolved.Requested)' -> '$targetModel'"
    }
    $content = Get-Content -Path $_.FullName -Raw
    $newContent = Set-ModelInFrontmatter -Content $content -Model $targetModel

    if ($newContent -ne $content) {
        if (-not $WhatIf) {
            Set-Content -Path $_.FullName -Value $newContent -Encoding UTF8
        }
        $updated++
        Write-Host "[ok] $agentName -> $targetModel"
    } else {
        $skipped++
    }
}

Write-Host ""
Write-Host "Done: $updated updated, $skipped skipped"

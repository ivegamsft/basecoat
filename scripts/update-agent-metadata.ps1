#!/usr/bin/env pwsh
# update-agent-metadata.ps1
# Adds model_tier, task_phase, and interaction_type to all agent frontmatter metadata.
# Also fixes memory-promoter.agent.md which is missing model: and allowed_skills:.

$agentsDir = Join-Path $PSScriptRoot "..\agents"

# Full taxonomy: agent-name -> [model_tier, task_phase, interaction_type]
$taxonomy = @{
    "agent-designer"              = @("balanced",  "build",   "collaborative")
    "agentops"                    = @("balanced",  "operate", "collaborative")
    "api-designer"                = @("reasoning", "plan",    "collaborative")
    "api-security"                = @("reasoning", "test",    "collaborative")
    "app-inventory"               = @("balanced",  "plan",    "autonomous")
    "azure-landing-zone"          = @("reasoning", "deploy",  "collaborative")
    "backend-dev"                 = @("balanced",  "build",   "collaborative")
    "chaos-engineer"              = @("balanced",  "test",    "autonomous")
    "code-review"                 = @("balanced",  "test",    "collaborative")
    "config-auditor"              = @("fast",      "operate", "reactive")
    "container-security"          = @("balanced",  "test",    "collaborative")
    "containerization-planner"    = @("reasoning", "plan",    "collaborative")
    "contract-testing"            = @("balanced",  "test",    "collaborative")
    "data-architect"              = @("reasoning", "plan",    "collaborative")
    "data-integrity"              = @("balanced",  "test",    "autonomous")
    "data-pipeline"               = @("balanced",  "build",   "collaborative")
    "data-tier"                   = @("balanced",  "build",   "collaborative")
    "database-migration"          = @("balanced",  "deploy",  "collaborative")
    "dataops"                     = @("balanced",  "deploy",  "collaborative")
    "dependency-lifecycle"        = @("fast",      "operate", "autonomous")
    "dependency-update-advisor"   = @("balanced",  "operate", "collaborative")
    "devops-engineer"             = @("balanced",  "deploy",  "collaborative")
    "domain-designer"             = @("reasoning", "plan",    "collaborative")
    "dotnet-modernization-advisor"= @("reasoning", "build",   "collaborative")
    "e2e-test-strategy"           = @("balanced",  "test",    "collaborative")
    "exploratory-charter"         = @("balanced",  "test",    "collaborative")
    "feedback-loop"               = @("fast",      "operate", "reactive")
    "finops-advisor"              = @("balanced",  "operate", "collaborative")
    "frontend-dev"                = @("balanced",  "build",   "collaborative")
    "github-security-posture"     = @("balanced",  "operate", "collaborative")
    "gitops-engineer"             = @("balanced",  "deploy",  "collaborative")
    "guardrail"                   = @("fast",      "test",    "reactive")
    "guidance-author"             = @("balanced",  "build",   "collaborative")
    "guidance-reviewer"           = @("balanced",  "test",    "collaborative")
    "ha-architect"                = @("reasoning", "plan",    "collaborative")
    "hardening-advisor"           = @("reasoning", "test",    "collaborative")
    "identity-architect"          = @("reasoning", "plan",    "collaborative")
    "incident-responder"          = @("reasoning", "operate", "reactive")
    "infrastructure-deploy"       = @("balanced",  "deploy",  "autonomous")
    "issue-triage"                = @("fast",      "plan",    "autonomous")
    "legacy-modernization"        = @("reasoning", "build",   "collaborative")
    "llmops"                      = @("balanced",  "deploy",  "collaborative")
    "manual-test-strategy"        = @("balanced",  "test",    "collaborative")
    "mcp-developer"               = @("balanced",  "build",   "collaborative")
    "memory-curator"              = @("fast",      "operate", "autonomous")
    "memory-promoter"             = @("fast",      "operate", "autonomous")
    "merge-coordinator"           = @("fast",      "deploy",  "autonomous")
    "middleware-dev"              = @("balanced",  "build",   "collaborative")
    "mlops"                       = @("balanced",  "deploy",  "collaborative")
    "new-customization"           = @("fast",      "build",   "autonomous")
    "observability-engineer"      = @("balanced",  "operate", "collaborative")
    "penetration-test"            = @("reasoning", "test",    "autonomous")
    "performance-analyst"         = @("balanced",  "test",    "collaborative")
    "policy-as-code-compliance"   = @("reasoning", "deploy",  "collaborative")
    "product-manager"             = @("reasoning", "plan",    "collaborative")
    "production-readiness"        = @("balanced",  "deploy",  "collaborative")
    "project-onboarding"          = @("balanced",  "plan",    "autonomous")
    "prompt-coach"                = @("balanced",  "build",   "collaborative")
    "prompt-engineer"             = @("balanced",  "build",   "collaborative")
    "release-impact-advisor"      = @("balanced",  "deploy",  "collaborative")
    "release-manager"             = @("balanced",  "deploy",  "collaborative")
    "resilience-reviewer"         = @("balanced",  "test",    "collaborative")
    "retro-facilitator"           = @("balanced",  "plan",    "collaborative")
    "rollout-basecoat"            = @("balanced",  "deploy",  "autonomous")
    "secrets-manager"             = @("balanced",  "operate", "collaborative")
    "security-analyst"            = @("reasoning", "test",    "collaborative")
    "security-monitor"            = @("balanced",  "operate", "reactive")
    "security-operations"         = @("balanced",  "operate", "collaborative")
    "self-healing-ci"             = @("fast",      "deploy",  "reactive")
    "solution-architect"          = @("reasoning", "plan",    "collaborative")
    "sprint-planner"              = @("balanced",  "plan",    "collaborative")
    "sprint-retrospective"        = @("balanced",  "plan",    "collaborative")
    "sre-engineer"                = @("balanced",  "operate", "reactive")
    "strategy-to-automation"      = @("reasoning", "plan",    "collaborative")
    "supply-chain-security"       = @("reasoning", "test",    "collaborative")
    "tech-writer"                 = @("balanced",  "build",   "collaborative")
    "ux-designer"                 = @("balanced",  "plan",    "collaborative")
}

$updated = 0
$skipped = 0
$errors  = 0

foreach ($file in Get-ChildItem -Path $agentsDir -Filter "*.agent.md") {
    $baseName = $file.BaseName -replace '\.agent$', ''
    # Extract actual agent name from new naming convention: basecoat-XX-category-agent-name -> agent-name
    $agentName = $baseName -replace '^basecoat-\d+-\w+-', ''
    $content   = Get-Content $file.FullName -Raw

    if (-not $taxonomy.ContainsKey($agentName)) {
        Write-Warning "No taxonomy entry for '$agentName' (file: $baseName) — skipping"
        $skipped++
        continue
    }

    $tier    = $taxonomy[$agentName][0]
    $phase   = $taxonomy[$agentName][1]
    $intType = $taxonomy[$agentName][2]

    # Skip if all three taxonomy fields already present
    if ($content -match 'model_tier:' -and $content -match 'task_phase:' -and $content -match 'interaction_type:') {
        Write-Host "  [skip] $agentName — taxonomy fields already present"
        $skipped++
        continue
    }

    # Build the three lines to insert (2-space indent matching metadata children)
    $inject = "  model_tier: `"$tier`"`n  task_phase: `"$phase`"`n  interaction_type: `"$intType`""

    # Insert after the audience: line (handles both inline array and multiline formats)
    # Pattern: audience line followed by optional continuation lines (starting with spaces+-)
    # then the next top-level key or end of frontmatter
    $newContent = $content -replace '(?m)([ \t]+audience:[^\n]*(?:\n[ \t]+-[^\n]*)*)(\n(?![ \t])|\n---)', "`$1`n$inject`$2"

    if ($newContent -eq $content) {
        # audience: not found — append taxonomy fields at end of metadata block before next top-level key
        Write-Warning "  [warn] $agentName — 'audience:' not found; appending after maturity:"
        $newContent = $content -replace '(?m)([ \t]+maturity:[^\n]*)(\n(?![ \t])|\n---)', "`$1`n$inject`$2"
    }

    if ($newContent -eq $content) {
        Write-Warning "  [warn] $agentName — could not locate insertion point; manual fix needed"
        $errors++
        continue
    }

    # Fix memory-promoter missing model: and allowed_skills:
    if ($agentName -eq 'memory-promoter') {
        if ($newContent -notmatch '(?m)^model:') {
            $newContent = $newContent -replace '(?m)(^allowed-tools:[^\n]*)', "model: claude-haiku-4.5`n`$1"
        }
        if ($newContent -notmatch 'allowed_skills:') {
            $newContent = $newContent -replace '(?m)(^allowed-tools:[^\n]*)', "`$1`nallowed_skills: []"
        }
    }

    Set-Content -Path $file.FullName -Value $newContent -NoNewline
    Write-Host "  [ok]   $agentName ($tier / $phase / $intType)"
    $updated++
}

Write-Host ""
Write-Host "Done: $updated updated, $skipped skipped, $errors errors"

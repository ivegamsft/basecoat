#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Add metadata.category field to all SKILL.md files.

.DESCRIPTION
    Automatically assigns category to skills based on naming patterns.
    Preserves existing categories and frontmatter structure.
#>

param(
    [string]$SkillsDir = 'skills'
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$SkillsDir = Join-Path $repoRoot $SkillsDir

# Category mapping based on skill name patterns
$categoryMap = @{
    # Architecture & Design
    'agent-design' = 'architecture'
    'api-design' = 'architecture'
    'architecture' = 'architecture'
    'domain-driven-design' = 'architecture'
    'decision-log-capture' = 'architecture'
    'factory-state-machine' = 'architecture'
    'cqrs-event-sourcing' = 'architecture'
    'twelve-factor' = 'architecture'
    'app-inventory' = 'architecture'
    
    # Security
    'api-security' = 'security'
    'security' = 'security'
    'github-security-posture' = 'security'
    'penetration-testing' = 'security'
    'public-safe-sanitization' = 'security'
    'supply-chain-security' = 'security'
    'identity-migration' = 'security'
    'security-operations' = 'security'
    
    # Audit & Operations (misc)
    'agentops-audit' = 'operations'
    'api-audit' = 'operations'
    'backend-audit' = 'operations'
    'ci-audit' = 'operations'
    'data-tier-audit' = 'operations'
    'frontend-audit' = 'operations'
    'infrastructure-audit' = 'operations'
    'landing-zone-audit' = 'operations'
    'mcp-audit' = 'operations'
    'release-audit' = 'operations'
    'sprint-closeout-audit' = 'operations'
    'azure-policy-audit' = 'operations'
    'devops-audit' = 'operations'
    
    # Azure & Infrastructure
    'azure-container-apps' = 'infrastructure'
    'azure-devops-rest' = 'infrastructure'
    'azure-identity' = 'infrastructure'
    'azure-identity-audit' = 'infrastructure'
    'azure-landing-zone' = 'infrastructure'
    'azure-linux-app-service' = 'infrastructure'
    'azure-networking' = 'infrastructure'
    'azure-policy' = 'infrastructure'
    'azure-waf-review' = 'infrastructure'
    'environment-bootstrap' = 'infrastructure'
    'dev-containers' = 'infrastructure'
    'gitops' = 'infrastructure'
    'git-worktrees' = 'infrastructure'
    'docs-site' = 'infrastructure'
    'mcp-development' = 'infrastructure'
    'container-build-assessment' = 'infrastructure'
    'container-migration' = 'infrastructure'
    'electron-apps' = 'infrastructure'
    
    # Database & Data
    'data-tier' = 'data'
    'database-migration' = 'data'
    'entity-framework-migration' = 'data'
    'service-bus-migration' = 'data'
    'bom-schema' = 'data'
    'bom-validation' = 'data'
    
    # Development & Modernization
    'backend-dev' = 'development'
    'frontend-dev' = 'development'
    'dotnet-modernization' = 'modernization'
    'cross-stack-modernization' = 'modernization'
    'e2e-testing' = 'testing'
    'contract-testing' = 'testing'
    'manual-test-strategy' = 'testing'
    'performance-profiling' = 'testing'
    'refactoring' = 'development'
    'receiving-code-review' = 'development'
    'code-review' = 'development'
    'merge-conflict-mediator' = 'development'
    'tech-debt' = 'development'
    'documentation' = 'development'
    'task-decomposition' = 'development'
    'create-skill' = 'development'
    'create-instruction' = 'development'
    'ux' = 'development'
    'lexicon' = 'development'
    'skill-scripts' = 'development'
    'devops' = 'development'
    
    # Operations & Process
    'build-failure-triage' = 'operations'
    'issue-triage' = 'operations'
    'orphaned-pr-triage' = 'operations'
    'sprint-planner' = 'operations'
    'sprint-management' = 'operations'
    'sprint-retrospective' = 'operations'
    'sprint-closeout' = 'operations'
    'backlog-burndown' = 'operations'
    'standup-signal-extraction' = 'operations'
    'handoff' = 'operations'
    'escalation-routing' = 'operations'
    'dependency-blocker-monitoring' = 'operations'
    'change-isolation' = 'operations'
    'failure-pattern-process' = 'operations'
    's4-deployment-checklist' = 'operations'
    's4-rollback-testing' = 'operations'
    'production-readiness' = 'operations'
    'ha-resilience' = 'operations'
    'rollout-basecoat' = 'operations'
    'release-notes' = 'operations'
    'basecoat' = 'operations'
    'takt-time-measurement' = 'operations'
    'station-bottleneck-analyzer' = 'operations'
    'observability' = 'operations'
    'ci-flake-quarantine' = 'testing'
    'copilot-usage-analytics' = 'operations'
    'memory-promoter' = 'operations'
    'sprint-project-mapper' = 'operations'
    'human-in-the-loop' = 'operations'
}

$updated = 0
$skipped = 0

Get-ChildItem -Path $SkillsDir -Directory | ForEach-Object {
    $skillName = $_.Name
    $skillMd = Join-Path $_ "SKILL.md"
    
    if (-not (Test-Path $skillMd)) {
        return
    }
    
    $content = Get-Content $skillMd -Raw
    
    # Check if already has category
    if ($content -match '(?m)^category\s*:') {
        "Skipping $skillName (already has category)"
        $skipped++
        return
    }
    
    # Get the category
    $category = $categoryMap[$skillName]
    if (-not $category) {
        # Default category if not in map
        $category = "general"
    }
    
    # Parse frontmatter
    if ($content -match '(?s)^---\s*\n(.*?)\n---') {
        $frontmatter = $Matches[1]
        $rest = $content.Substring($Matches[0].Length)
        
        # Add category to frontmatter (before closing ---)
        $lines = $frontmatter -split "`n"
        $newLines = @()
        $added = $false
        
        foreach ($line in $lines) {
            $newLines += $line
            # Add category after 'version' or 'tags' if they exist, otherwise after description
            if (($line -match '^\s*version\s*:' -or $line -match '^\s*tags\s*:') -and -not $added) {
                $newLines += "category: $category"
                $added = $true
            }
        }
        
        # If not added yet, add it before closing ---
        if (-not $added) {
            $newLines += "category: $category"
        }
        
        $newFrontmatter = $newLines -join "`n"
        $newContent = "---`n$newFrontmatter`n---$rest"
        
        Set-Content -Path $skillMd -Value $newContent -NoNewline
        "Updated $skillName (category: $category)"
        $updated++
    }
}

Write-Host ""
Write-Host "Summary: Updated $updated skills, skipped $skipped (already have category)"

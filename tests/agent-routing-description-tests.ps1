$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$agentFiles = @(
    'agentic-sdlc-autonomy.agent.md',
    'basecoat-10-core-change-isolation-architect.agent.md',
    'basecoat-10-core-exploratory-charter.agent.md',
    'basecoat-10-core-merge-coordinator.agent.md',
    'basecoat-10-core-new-customization.agent.md',
    'basecoat-10-core-product-manager.agent.md',
    'basecoat-10-core-prompt-coach.agent.md',
    'basecoat-10-core-prompt-engineer.agent.md',
    'basecoat-10-core-solution-architect.agent.md',
    'basecoat-10-core-strategy-to-automation.agent.md',
    'basecoat-10-core-tech-writer.agent.md',
    'basecoat-10-core-ux-designer.agent.md',
    'basecoat-20-lang-dotnet-modernization-advisor.agent.md',
    'basecoat-40-azure-azure-landing-zone.agent.md',
    'basecoat-60-workflow-data-pipeline.agent.md',
    'basecoat-80-data-data-integrity.agent.md',
    'basecoat-90-quality-manual-test-strategy.agent.md'
)

$missingClauses = @()
foreach ($agentFile in $agentFiles) {
    $path = Join-Path $repoRoot "agents/$agentFile"
    $content = Get-Content -LiteralPath $path -Raw
    if ($content -notmatch '(?s)^---.*?description:.*?USE FOR:.*?DO NOT USE FOR:.*?---') {
        $missingClauses += $agentFile
    }
}

if ($missingClauses.Count -gt 0) {
    throw "Agent routing descriptions are incomplete: $($missingClauses -join ', ')"
}

Write-Host "Agent routing description tests passed for $($agentFiles.Count) agents."

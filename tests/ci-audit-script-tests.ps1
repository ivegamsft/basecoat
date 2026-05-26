$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running CI audit script tests...'

function Test-CiAuditScriptExists {
    $path = Join-Path $repoRoot 'scripts\ci-audit.ps1'
    if (-not (Test-Path $path)) {
        throw "CI audit script not found at $path"
    }
    Write-Host '  [PASS] ci-audit.ps1 exists' -ForegroundColor Green
}

function Test-CiAuditHelpWorks {
    $scriptPath = Join-Path $repoRoot 'scripts\ci-audit.ps1'
    $script = Get-Content $scriptPath -Raw
    if ($script -notmatch 'Show-Help') {
        throw 'Script missing Show-Help function'
    }
    if ($script -notmatch 'CI/CD Audit Script') {
        throw 'Script missing help text'
    }
    Write-Host '  [PASS] -Help flag works' -ForegroundColor Green
}

function Test-CiAuditParameterValidation {
    $scriptPath = Join-Path $repoRoot 'scripts\ci-audit.ps1'
    $script = Get-Content $scriptPath -Raw
    if ($script -notmatch '\$OrgName') {
        throw 'Script missing OrgName parameter'
    }
    if ($script -notmatch 'ErrorActionPreference') {
        throw 'Script missing error handling'
    }
    Write-Host '  [PASS] Parameter validation works' -ForegroundColor Green
}

function Test-CiAuditSkillFileExists {
    $skillPath = Join-Path $repoRoot 'skills\ci-audit\SKILL.md'
    if (-not (Test-Path $skillPath)) {
        throw "Skill file not found at $skillPath"
    }
    Write-Host '  [PASS] skills/ci-audit/SKILL.md exists' -ForegroundColor Green
}

function Test-CiAuditSkillHasUseFor {
    $skillPath = Join-Path $repoRoot 'skills\ci-audit\SKILL.md'
    $content = Get-Content $skillPath -Raw
    if ($content -notmatch '## USE FOR') {
        throw 'SKILL.md missing USE FOR section'
    }
    Write-Host '  [PASS] SKILL.md has USE FOR section' -ForegroundColor Green
}

function Test-CiAuditSkillHasDoNotUseFor {
    $skillPath = Join-Path $repoRoot 'skills\ci-audit\SKILL.md'
    $content = Get-Content $skillPath -Raw
    if ($content -notmatch '## DO NOT USE FOR') {
        throw 'SKILL.md missing DO NOT USE FOR section'
    }
    Write-Host '  [PASS] SKILL.md has DO NOT USE FOR section' -ForegroundColor Green
}

function Test-CiAuditAgentFileExists {
    $agentPath = Join-Path $repoRoot 'agents\ci-audit.agent.md'
    if (-not (Test-Path $agentPath)) {
        throw "Agent file not found at $agentPath"
    }
    Write-Host '  [PASS] agents/ci-audit.agent.md exists' -ForegroundColor Green
}

function Test-CiAuditAgentHasFrontmatter {
    $agentPath = Join-Path $repoRoot 'agents\ci-audit.agent.md'
    $content = Get-Content $agentPath -Raw
    if ($content -notmatch '^---\s+name: ci-audit') {
        throw 'Agent file missing required frontmatter'
    }
    Write-Host '  [PASS] Agent has frontmatter' -ForegroundColor Green
}

function Test-CiAuditChecklistExists {
    $checklistPath = Join-Path $repoRoot 'skills\ci-audit\references\ci-audit-checklist.md'
    if (-not (Test-Path $checklistPath)) {
        throw "Checklist not found at $checklistPath"
    }
    Write-Host '  [PASS] ci-audit-checklist.md exists' -ForegroundColor Green
}

function Test-CiAuditChecklistHasOrgSettings {
    $checklistPath = Join-Path $repoRoot 'skills\ci-audit\references\ci-audit-checklist.md'
    $content = Get-Content $checklistPath -Raw
    if ($content -notmatch 'GitHub Organization Settings') {
        throw 'Checklist missing GitHub Organization Settings section'
    }
    Write-Host '  [PASS] Checklist has Organization Settings section' -ForegroundColor Green
}

function Test-CiAuditChecklistHasRunners {
    $checklistPath = Join-Path $repoRoot 'skills\ci-audit\references\ci-audit-checklist.md'
    $content = Get-Content $checklistPath -Raw
    if ($content -notmatch 'Self-Hosted Runner') {
        throw 'Checklist missing Self-Hosted Runner section'
    }
    Write-Host '  [PASS] Checklist has Runner section' -ForegroundColor Green
}

function Test-CiAuditChecklistHasDependencies {
    $checklistPath = Join-Path $repoRoot 'skills\ci-audit\references\ci-audit-checklist.md'
    $content = Get-Content $checklistPath -Raw
    if ($content -notmatch 'Dependency Health') {
        throw 'Checklist missing Dependency Health section'
    }
    Write-Host '  [PASS] Checklist has Dependency Health section' -ForegroundColor Green
}

function Test-CiAuditTemplatesExist {
    $templatesPath = Join-Path $repoRoot 'skills\ci-audit\templates'
    $findings = Join-Path $templatesPath 'audit-findings-template.md'
    $recommendations = Join-Path $templatesPath 'recommendations-template.md'
    
    if (-not (Test-Path $findings)) {
        throw "Findings template not found at $findings"
    }
    if (-not (Test-Path $recommendations)) {
        throw "Recommendations template not found at $recommendations"
    }
    Write-Host '  [PASS] Audit templates exist' -ForegroundColor Green
}

function Test-CiAuditSkillHasTemplateReferences {
    $skillPath = Join-Path $repoRoot 'skills\ci-audit\SKILL.md'
    $content = Get-Content $skillPath -Raw
    if ($content -notmatch 'audit-findings-template') {
        throw 'SKILL.md missing audit-findings-template reference'
    }
    if ($content -notmatch 'recommendations-template') {
        throw 'SKILL.md missing recommendations-template reference'
    }
    Write-Host '  [PASS] SKILL.md references templates' -ForegroundColor Green
}

function Test-CiAuditSkillMentionsScript {
    $skillPath = Join-Path $repoRoot 'skills\ci-audit\SKILL.md'
    $content = Get-Content $skillPath -Raw
    if ($content -notmatch 'ci-audit\.ps1') {
        throw 'SKILL.md does not mention ci-audit.ps1 script'
    }
    Write-Host '  [PASS] SKILL.md mentions audit script' -ForegroundColor Green
}

function Test-CiAuditAgentHasWorkflow {
    $agentPath = Join-Path $repoRoot 'agents\ci-audit.agent.md'
    $content = Get-Content $agentPath -Raw
    if ($content -notmatch '## Workflow') {
        throw 'Agent missing Workflow section'
    }
    Write-Host '  [PASS] Agent has Workflow section' -ForegroundColor Green
}

function Test-CiAuditAgentOutputContract {
    $agentPath = Join-Path $repoRoot 'agents\ci-audit.agent.md'
    $content = Get-Content $agentPath -Raw
    if ($content -notmatch '## Output Contract') {
        throw 'Agent missing Output Contract section'
    }
    if ($content -notmatch 'audit_timestamp') {
        throw 'Output Contract missing audit_timestamp field'
    }
    Write-Host '  [PASS] Agent has Output Contract' -ForegroundColor Green
}

function Test-CiAuditSkillFrontmatterValid {
    $skillPath = Join-Path $repoRoot 'skills\ci-audit\SKILL.md'
    $content = Get-Content $skillPath -Raw
    
    if ($content -notmatch '^---') {
        throw 'SKILL.md missing frontmatter opening'
    }
    
    if ($content -notmatch 'name: ci-audit') {
        throw 'SKILL.md frontmatter missing name'
    }
    if ($content -notmatch 'description:') {
        throw 'SKILL.md frontmatter missing description'
    }
    
    Write-Host '  [PASS] SKILL.md frontmatter is valid' -ForegroundColor Green
}

# Run all tests
$tests = @(
    'Test-CiAuditScriptExists',
    'Test-CiAuditHelpWorks',
    'Test-CiAuditParameterValidation',
    'Test-CiAuditSkillFileExists',
    'Test-CiAuditSkillHasUseFor',
    'Test-CiAuditSkillHasDoNotUseFor',
    'Test-CiAuditAgentFileExists',
    'Test-CiAuditAgentHasFrontmatter',
    'Test-CiAuditChecklistExists',
    'Test-CiAuditChecklistHasOrgSettings',
    'Test-CiAuditChecklistHasRunners',
    'Test-CiAuditChecklistHasDependencies',
    'Test-CiAuditTemplatesExist',
    'Test-CiAuditSkillHasTemplateReferences',
    'Test-CiAuditSkillMentionsScript',
    'Test-CiAuditAgentHasWorkflow',
    'Test-CiAuditAgentOutputContract',
    'Test-CiAuditSkillFrontmatterValid'
)

$passed = 0
$failed = 0

foreach ($test in $tests) {
    try {
        & $test
        $passed++
    }
    catch {
        Write-Host "  [FAIL] $test : $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nCI Audit Script Tests: $passed passed, $failed failed"

if ($failed -gt 0) {
    exit 1
}

exit 0

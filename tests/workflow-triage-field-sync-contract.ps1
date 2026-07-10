#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract gate ensuring issue-triage labels align with issue-field-sync field mapping.

.DESCRIPTION
    Fails when issue-triage.md and issue-field-sync.yml drift so that a label the triage
    agent applies can no longer be translated into a native issue Type or Priority field
    by the field-sync workflow.

    Specifically validates:
    - issue-field-sync.yml triggers on issues.labeled so it fires after triage applies labels
    - All canonical type labels from the triage taxonomy appear in the field-sync type array
    - All canonical priority labels from the triage taxonomy appear in the field-sync priority map
    - The triage prompt documents the field-sync behaviour (keeping docs in sync)
    - All canonical type and priority labels from triage are mapped explicitly in field-sync
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot      = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$triageMdPath  = Join-Path $repoRoot '.github/workflows/issue-triage.md'
$fieldSyncPath = Join-Path $repoRoot '.github/workflows/issue-field-sync.yml'

foreach ($f in @($triageMdPath, $fieldSyncPath)) {
    if (-not (Test-Path $f)) { throw "Required file not found: $f" }
}

$triage    = Get-Content $triageMdPath  -Raw
$fieldSync = Get-Content $fieldSyncPath -Raw

$passed   = 0
$failed   = 0
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Contains {
    param([string]$Name, [string]$Content, [string]$Pattern)
    if ($Content -match [regex]::Escape($Pattern)) {
        Write-Host "    PASS $Name"
        $script:passed++
    } else {
        Write-Host "    FAIL $Name — pattern not found: $Pattern" -ForegroundColor Red
        $script:failed++
        $script:failures.Add($Name)
    }
}

function Assert-Regex {
    param([string]$Name, [string]$Content, [string]$Pattern)
    if ($Content -match $Pattern) {
        Write-Host "    PASS $Name"
        $script:passed++
    } else {
        Write-Host "    FAIL $Name — regex not matched: $Pattern" -ForegroundColor Red
        $script:failed++
        $script:failures.Add($Name)
    }
}

Write-Host 'Running triage-field-sync contract checks...'

# ---------------------------------------------------------------------------
# Group 1: field-sync trigger alignment
# ---------------------------------------------------------------------------
Write-Host '  Group 1: field-sync trigger alignment'

Assert-Contains  -Name 'field-sync triggers on issues.labeled' `
    -Content $fieldSync `
    -Pattern '- labeled'

# ---------------------------------------------------------------------------
# Group 2: type label coverage
# Triage applies exactly these canonical type labels (from issue-triage.md taxonomy).
# field-sync must accept all of them in its ordered type label lookup array.
# ---------------------------------------------------------------------------
Write-Host '  Group 2: type label coverage in field-sync'

$canonicalTypeLabels = @('bug', 'enhancement', 'documentation', 'chore', 'security', 'question')

foreach ($label in $canonicalTypeLabels) {
    Assert-Contains `
        -Name "field-sync type array contains '$label'" `
        -Content $fieldSync `
        -Pattern "'$label'"
}

# Verify each canonical type is also present in the triage taxonomy
foreach ($label in $canonicalTypeLabels) {
    Assert-Regex `
        -Name "triage taxonomy documents '$label' type label" `
        -Content $triage `
        -Pattern "\b$label\b"
}

# ---------------------------------------------------------------------------
# Group 3: priority label coverage
# Triage applies exactly these canonical priority labels.
# field-sync must map each one to a non-null priority value.
# ---------------------------------------------------------------------------
Write-Host '  Group 3: priority label coverage in field-sync'

$canonicalPriorityLabels = @('priority:critical', 'priority:high', 'priority:medium', 'priority:low')
$expectedPriorityValues  = @{
    'priority:critical' = 'Urgent'
    'priority:high'     = 'High'
    'priority:medium'   = 'Medium'
    'priority:low'      = 'Low'
}

foreach ($label in $canonicalPriorityLabels) {
    Assert-Contains `
        -Name "field-sync priority map contains '$label'" `
        -Content $fieldSync `
        -Pattern "'$label'"
}

foreach ($kv in $expectedPriorityValues.GetEnumerator()) {
    Assert-Regex `
        -Name "field-sync maps '$($kv.Key)' to '$($kv.Value)'" `
        -Content $fieldSync `
        -Pattern "'$([regex]::Escape($kv.Key))':\s*'$([regex]::Escape($kv.Value))'"
}

# Verify each canonical priority is also present in the triage taxonomy
foreach ($label in $canonicalPriorityLabels) {
    Assert-Contains `
        -Name "triage taxonomy documents '$label' priority label" `
        -Content $triage `
        -Pattern $label
}

# ---------------------------------------------------------------------------
# Group 4: documentation alignment
# Triage prompt must state that canonical labels are mirrored into native fields.
# This keeps the prompt documentation in sync with the actual field-sync behaviour.
# ---------------------------------------------------------------------------
Write-Host '  Group 4: triage prompt documents field-sync behaviour'

Assert-Regex  -Name 'triage prompt mentions native Type field' `
    -Content $triage `
    -Pattern 'Type.*field|native.*type|issue.*Type'

Assert-Regex  -Name 'triage prompt mentions native Priority field' `
    -Content $triage `
    -Pattern 'Priority.*field|native.*priority|issue.*Priority'

# ---------------------------------------------------------------------------
# Group 5: no silent no-ops — field-sync handles each triage type label
# The type label array in field-sync is ordered; any label not in the list
# falls through to 'Task'.  Verify each canonical type either maps explicitly
# to Feature/Bug or is documented as falling to Task.
# ---------------------------------------------------------------------------
Write-Host '  Group 5: type-to-field mapping completeness'

# enhancement -> Feature
Assert-Regex  -Name "enhancement maps to 'Feature'" `
    -Content $fieldSync `
    -Pattern "'enhancement'[\s\S]*?'Feature'"

# bug and security -> Bug
Assert-Regex  -Name "bug or security maps to 'Bug'" `
    -Content $fieldSync `
    -Pattern "typeLabel\s*===\s*'bug'\s*\|\|\s*typeLabel\s*===\s*'security'"

# remaining types (documentation, chore, question) fall to Task
Assert-Regex  -Name "remaining types fall to 'Task'" `
    -Content $fieldSync `
    -Pattern "typeLabel[\s\S]*?'Task'"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })
if ($failures.Count -gt 0) {
    Write-Host 'Failed checks:' -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}

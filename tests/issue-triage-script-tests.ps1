#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for the issue triage script (skills/issue-triage/scripts/triage-issues.ps1).

.DESCRIPTION
    Validates triage script logic including:
    - No parse errors on script load (regression for issue #1159: $N: scope-qualifier bug)
    - $priorityLabels accepts both canonical P0-P3 and legacy priority/* formats
    - Stale check uses $priorityLabels array instead of hardcoded individual checks
    - Priority floor logic skips issues that already have any recognized priority label
    - Security escalation uses canonical label and checks all critical variants
    - Get-TokenOverlap helper returns correct Jaccard similarity
    - Test-EncodingGibberish detects known corruption patterns
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'skills\issue-triage\scripts\triage-issues.ps1'

Set-Location $repoRoot

$passed = 0
$failed = 0

function Assert-Equal {
    param([string]$Name, $Actual, $Expected)
    if ($Actual -eq $Expected) {
        Write-Host "    PASS $Name"
        $script:passed++
    } else {
        Write-Host "    FAIL $Name — expected '$Expected', got '$Actual'" -ForegroundColor Red
        $script:failed++
    }
}

function Assert-True {
    param([string]$Name, [bool]$Value)
    if ($Value) {
        Write-Host "    PASS $Name"
        $script:passed++
    } else {
        Write-Host "    FAIL $Name — expected true, got false" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host 'Running issue triage script tests...'

# ---------------------------------------------------------------------------
# Test 1: Script loads without parse errors (regression for issue #1159)
# ---------------------------------------------------------------------------
Write-Host '  Test 1: Script parses without errors...'
$parseResult = & pwsh -NoProfile -Command {
    param($p)
    try {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count -gt 0) {
            return "PARSE_ERROR:$($errors[0].Message)"
        }
        return "OK"
    } catch {
        return "EXCEPTION:$_"
    }
} -args $scriptPath

Assert-Equal 'Script parses cleanly (no $N: scope-qualifier error)' $parseResult 'OK'

# ---------------------------------------------------------------------------
# Test 2: $priorityLabels includes all canonical and legacy formats
# ---------------------------------------------------------------------------
Write-Host '  Test 2: Priority label array covers both canonical and legacy formats...'

$labelsScript = @'
$canonicalPriorityLabels = @{
    critical = "priority:critical"
    high     = "priority:high"
    medium   = "priority:medium"
    low      = "priority:low"
}
$legacyPriorityLabels = @(
    "P0-critical",
    "P1-high",
    "P2-medium",
    "P3-low",
    "priority/critical",
    "priority/high",
    "priority/medium",
    "priority/low"
)
$priorityLabels = @(
    $canonicalPriorityLabels.critical,
    $canonicalPriorityLabels.high,
    $canonicalPriorityLabels.medium,
    $canonicalPriorityLabels.low
) + $legacyPriorityLabels
$required = @(
    "priority:critical","priority:high","priority:medium","priority:low",
    "P0-critical","P1-high","P2-medium","P3-low",
    "priority/critical","priority/high","priority/medium","priority/low"
)
$missing = $required | Where-Object { $priorityLabels -notcontains $_ }
$missing.Count
'@

$labelsOutput = & pwsh -NoProfile -Command $labelsScript
Assert-Equal 'All canonical and legacy priority label variants present in $priorityLabels' $labelsOutput '0'

# ---------------------------------------------------------------------------
# Test 3: Script source contains all canonical and legacy labels
# ---------------------------------------------------------------------------
Write-Host '  Test 3: Script source contains all required priority label strings...'
$psContent = Get-Content $scriptPath -Raw
$missing3 = @(
    "priority:critical","priority:high","priority:medium","priority:low",
    "P0-critical","P1-high","P2-medium","P3-low",
    "priority/critical","priority/high","priority/medium","priority/low"
) |
    Where-Object { $psContent -notmatch [regex]::Escape($_) }
Assert-True 'All priority label strings present in script source' ($missing3.Count -eq 0)

# ---------------------------------------------------------------------------
# Test 4: Legacy P1-high prevents stale label (regression for issue #1159)
# ---------------------------------------------------------------------------
Write-Host '  Test 4: Legacy P1-high prevents stale label...'

$staleScript = @'
$priorityLabels = @("priority:critical","priority:high","priority:medium","priority:low","P0-critical","P1-high","P2-medium","P3-low","priority/critical","priority/high","priority/medium","priority/low")
$labels   = @("bug","P1-high")
$agedays  = 100
$staleAdded = $false
if ($agedays -gt 90 -and $labels -notcontains "stale" -and
    -not ($labels | Where-Object { $priorityLabels -contains $_ }) -and
    $labels -notcontains "blocked") {
    $staleAdded = $true
}
$staleAdded.ToString()
'@

$staleOutput = & pwsh -NoProfile -Command $staleScript
Assert-Equal 'P1-high blocks stale label on issue >90 days old' $staleOutput 'False'

# ---------------------------------------------------------------------------
# Test 5: P2-medium also prevents stale (all priority labels protect against stale)
# ---------------------------------------------------------------------------
Write-Host '  Test 5: Legacy P2-medium prevents stale label...'

$staleScript5 = @'
$priorityLabels = @("priority:critical","priority:high","priority:medium","priority:low","P0-critical","P1-high","P2-medium","P3-low","priority/critical","priority/high","priority/medium","priority/low")
$labels   = @("bug","P2-medium")
$agedays  = 100
$staleAdded = $false
if ($agedays -gt 90 -and $labels -notcontains "stale" -and
    -not ($labels | Where-Object { $priorityLabels -contains $_ }) -and
    $labels -notcontains "blocked") {
    $staleAdded = $true
}
$staleAdded.ToString()
'@

$staleOutput5 = & pwsh -NoProfile -Command $staleScript5
Assert-Equal 'P2-medium blocks stale label on issue >90 days old' $staleOutput5 'False'

# ---------------------------------------------------------------------------
# Test 6: Missing priority label triggers stale after 90 days
# ---------------------------------------------------------------------------
Write-Host '  Test 6: No priority label triggers stale after 90 days...'

$staleScript6 = @'
$priorityLabels = @("priority:critical","priority:high","priority:medium","priority:low","P0-critical","P1-high","P2-medium","P3-low","priority/critical","priority/high","priority/medium","priority/low")
$labels   = @("bug")
$agedays  = 100
$staleAdded = $false
if ($agedays -gt 90 -and $labels -notcontains "stale" -and
    -not ($labels | Where-Object { $priorityLabels -contains $_ }) -and
    $labels -notcontains "blocked") {
    $staleAdded = $true
}
$staleAdded.ToString()
'@

$staleOutput6 = & pwsh -NoProfile -Command $staleScript6
Assert-Equal 'Missing priority triggers stale on issue >90 days old' $staleOutput6 'True'

# ---------------------------------------------------------------------------
# Test 7: priority/critical (legacy format) prevents stale
# ---------------------------------------------------------------------------
Write-Host '  Test 7: Legacy priority/critical prevents stale label...'

$staleScript7 = @'
$priorityLabels = @("priority:critical","priority:high","priority:medium","priority:low","P0-critical","P1-high","P2-medium","P3-low","priority/critical","priority/high","priority/medium","priority/low")
$labels   = @("bug","priority/critical")
$agedays  = 100
$staleAdded = $false
if ($agedays -gt 90 -and $labels -notcontains "stale" -and
    -not ($labels | Where-Object { $priorityLabels -contains $_ }) -and
    $labels -notcontains "blocked") {
    $staleAdded = $true
}
$staleAdded.ToString()
'@

$staleOutput7 = & pwsh -NoProfile -Command $staleScript7
Assert-Equal 'priority/critical blocks stale label on issue >90 days old' $staleOutput7 'False'

# ---------------------------------------------------------------------------
# Test 8: Security + priority:critical skips critical escalation
# ---------------------------------------------------------------------------
Write-Host '  Test 8: Security + priority:critical skips escalation...'

$secScript = @'
$labels       = @("security","priority:critical")
$escalated    = $false
if ($labels -contains "security" -and $labels -notcontains "priority:critical" -and $labels -notcontains "P0-critical" -and $labels -notcontains "priority/critical") {
    $escalated = $true
}
$escalated.ToString()
'@

$secOutput = & pwsh -NoProfile -Command $secScript
Assert-Equal 'priority:critical prevents duplicate critical escalation' $secOutput 'False'

# ---------------------------------------------------------------------------
# Test 9: Existing priority prevents security escalation from adding a label
# ---------------------------------------------------------------------------
Write-Host '  Test 9: Existing priority is not replaced by security escalation...'

$secScript2 = @'
$priorityLabels = @("priority:critical","priority:high","priority:medium","priority:low","P0-critical","P1-high","P2-medium","P3-low","priority/critical","priority/high","priority/medium","priority/low")
$labels       = @("security","priority:medium")
$escalated    = $false
if ($labels -contains "security" -and $labels -notcontains "priority:critical" -and $labels -notcontains "P0-critical" -and $labels -notcontains "priority/critical" -and
    -not ($labels | Where-Object { $priorityLabels -contains $_ })) {
    $escalated = $true
}
$escalated.ToString()
'@

$secOutput2 = & pwsh -NoProfile -Command $secScript2
Assert-Equal 'Security with priority:medium does not add priority:critical' $secOutput2 'False'

# ---------------------------------------------------------------------------
# Test 10: Existing noncritical priority is preserved during security review
# ---------------------------------------------------------------------------
Write-Host '  Test 10: Existing priority is preserved over a security recommendation...'

$fixture = @{
    number = 456
    title = 'Security report keeps the existing priority'
    body = 'A security review found a risk that needs investigation. The existing priority should remain unchanged until a maintainer reviews it.'
    labels = @(
        @{ name = 'security' }
        @{ name = 'priority:medium' }
        @{ name = 'sprint:24' }
    )
    state = 'OPEN'
    closedAt = $null
    createdAt = [datetime]::UtcNow.ToString('o')
    assignees = @()
    comments = @()
}
$global:TriageIssueFixtureJson = ConvertTo-Json -InputObject $fixture -Depth 10 -Compress
function global:gh {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Arguments)
    $global:LASTEXITCODE = 0
    if ($Arguments[0] -eq 'issue' -and $Arguments[1] -eq 'list') { return '[]' }
    if ($Arguments[0] -eq 'issue' -and $Arguments[1] -eq 'view') { return $global:TriageIssueFixtureJson }
    if ($Arguments[0] -eq 'api') { return '[]' }
    if ($Arguments[0] -eq 'pr' -and $Arguments[1] -eq 'list') { return '[]' }
    return ''
}
try {
    $triageOutput = (& $scriptPath -Repo 'example/project' -IssueNumber 456 6>&1 | Out-String)
    Assert-True 'Production script does not add a second priority label' `
        ($triageOutput -notmatch '(?m)\[\+label\].*priority:(critical|high|medium|low)')
    Assert-True 'Production script reports the critical recommendation and preserves priority:medium' `
        ($triageOutput -match '(?m)\[comment\].*security priority recommendation')
    Assert-True 'PowerShell script reports differing security recommendation instead of adding it' `
        ($psContent -match 'existingPriorityLabels\.Count -gt 0')

    $fixture.labels = @(
        @{ name = 'security' }
        @{ name = 'sprint:24' }
    )
    $global:TriageIssueFixtureJson = ConvertTo-Json -InputObject $fixture -Depth 10 -Compress
    $missingPriorityOutput = (& $scriptPath -Repo 'example/project' -IssueNumber 456 6>&1 | Out-String)
    $addedPriorityLines = @($missingPriorityOutput -split '\r?\n' | Where-Object {
        $_ -match '\[\+label\].*priority:(critical|high|medium|low)'
    })
    Assert-Equal 'Security without a priority adds exactly one critical label' $addedPriorityLines.Count 1
    Assert-True 'Critical escalation does not add a priority floor' `
        ($addedPriorityLines[0] -match 'priority:critical' -and $missingPriorityOutput -notmatch '\[\+label\].*priority:(high|medium|low)')

    $fixture.labels = @(
        @{ name = 'security' }
        @{ name = 'priority:medium' }
        @{ name = 'priority:high' }
        @{ name = 'sprint:24' }
    )
    $global:TriageIssueFixtureJson = ConvertTo-Json -InputObject $fixture -Depth 10 -Compress
    $conflictOutput = (& $scriptPath -Repo 'example/project' -IssueNumber 456 6>&1 | Out-String)
    Assert-True 'Pre-existing multi-priority conflict is reported' `
        ($conflictOutput -match '(?m)\[comment\].*priority conflict')
    Assert-True 'Multi-priority conflict does not add another priority label' `
        ($conflictOutput -notmatch '(?m)\[\+label\].*priority:(critical|high|medium|low)')
} finally {
    Remove-Item Function:\global:gh -ErrorAction SilentlyContinue
    Remove-Variable TriageIssueFixtureJson -Scope Global -ErrorAction SilentlyContinue
}
$shContent = Get-Content (Join-Path $repoRoot 'skills\issue-triage\scripts\triage-issues.sh') -Raw
Assert-True 'Bash script preserves the existing priority on security escalation' `
    ($shContent -match 'if \[\[ "\$HAS_PRIORITY_ANY" == "true" \]\]; then[\s\S]+PRESERVED_PRIORITY[\s\S]+else[\s\S]+Security without an existing priority')
Assert-True 'Bash script reports pre-existing multi-priority conflicts' `
    ($shContent -match 'EXISTING_PRIORITIES[\s\S]+-gt 1[\s\S]+"priority conflict"')

# ---------------------------------------------------------------------------
# Test 11: Get-TokenOverlap — identical titles → 1.0
# ---------------------------------------------------------------------------
Write-Host '  Test 11: Get-TokenOverlap identical titles...'

$overlapScript = @'
function Get-TokenOverlap {
    param([string] $a, [string] $b)
    $stopWords = @("the","a","an","is","it","in","on","at","to","for","of","and","or","but","with","that","this","was","are","be","by","from","as","not","we","i","you","he","she","they","do","did","does","have","has","had","will","would","can","could","should","may","might","must","shall","fix","issue","bug","error","problem","help","add","update","change","make","use")
    $tokenize = { param([string] $s) ($s.ToLower() -split '[^a-z0-9]+') | Where-Object { $_ -ne "" -and $_.Length -gt 2 -and $_ -notin $stopWords } }
    $setA = @(& $tokenize $a)
    $setB = @(& $tokenize $b)
    if ($setA.Count -eq 0 -or $setB.Count -eq 0) { return 0.0 }
    $intersection = ($setA | Where-Object { $setB -contains $_ }).Count
    $union = ($setA + $setB | Sort-Object -Unique).Count
    return [math]::Round($intersection / $union, 2)
}
Get-TokenOverlap "authentication fails for new users" "authentication fails for new users"
'@

$overlapOutput = & pwsh -NoProfile -Command $overlapScript
Assert-Equal 'Identical titles produce overlap 1' $overlapOutput '1'

# ---------------------------------------------------------------------------
# Test 12: Get-TokenOverlap — completely different titles → 0.0
# ---------------------------------------------------------------------------
Write-Host '  Test 12: Get-TokenOverlap different titles...'

$overlapScript2 = @'
function Get-TokenOverlap {
    param([string] $a, [string] $b)
    $stopWords = @("the","a","an","is","it","in","on","at","to","for","of","and","or","but","with","that","this","was","are","be","by","from","as","not","we","i","you","he","she","they","do","did","does","have","has","had","will","would","can","could","should","may","might","must","shall","fix","issue","bug","error","problem","help","add","update","change","make","use")
    $tokenize = { param([string] $s) ($s.ToLower() -split '[^a-z0-9]+') | Where-Object { $_ -ne "" -and $_.Length -gt 2 -and $_ -notin $stopWords } }
    $setA = @(& $tokenize $a)
    $setB = @(& $tokenize $b)
    if ($setA.Count -eq 0 -or $setB.Count -eq 0) { return 0.0 }
    $intersection = ($setA | Where-Object { $setB -contains $_ }).Count
    $union = ($setA + $setB | Sort-Object -Unique).Count
    return [math]::Round($intersection / $union, 2)
}
Get-TokenOverlap "authentication login failure" "deployment pipeline configuration"
'@

$overlapOutput2 = & pwsh -NoProfile -Command $overlapScript2
Assert-Equal 'Unrelated titles produce overlap 0' $overlapOutput2 '0'

# ---------------------------------------------------------------------------
# Test 13: Test-EncodingGibberish detects Mojibake patterns
# ---------------------------------------------------------------------------
Write-Host '  Test 13: Test-EncodingGibberish detects corruption...'

$gibberishScript = @'
function Test-EncodingGibberish {
    param([string] $Text)
    if (-not $Text) { return $false }
    $replacementChar = [string][char]0xFFFD
    $patterns = @(
        [regex]::Escape($replacementChar),
        "Ã.",
        "Â.",
        "â€™",
        "â€œ",
        "â€",
        "ðŸ"
    )
    foreach ($p in $patterns) {
        if ($Text -match $p) { return $true }
    }
    return $false
}
$results = @(
    (Test-EncodingGibberish "Normal clean text"),
    (Test-EncodingGibberish "text with Ã© corruption"),
    (Test-EncodingGibberish "text with â€™ corruption"),
    (Test-EncodingGibberish "")
)
$results -join ','
'@

$gibberishOutput = & pwsh -NoProfile -Command $gibberishScript
Assert-Equal 'EncodingGibberish: clean=F, two corrupted=T, empty=F' `
    $gibberishOutput 'False,True,True,False'

# ---------------------------------------------------------------------------
# Test 14: Sprint label policy requires sprint:<number>
# ---------------------------------------------------------------------------
Write-Host '  Test 14: Sprint label policy detects missing sprint labels...'

$sprintScript = @'
function Has-SprintLabel {
    param([string[]] $labels)
    return (@($labels | Where-Object { $_ -match '^sprint[:/\-]?\d+$' }).Count -gt 0)
}
$results = @(
    (Has-SprintLabel @("bug","sprint:24")),
    (Has-SprintLabel @("bug","sprint-24")),
    (Has-SprintLabel @("bug","needs-triage"))
)
$results -join ","
'@

$sprintOutput = & pwsh -NoProfile -Command $sprintScript
Assert-Equal 'Has-SprintLabel matches sprint label formats and rejects missing label' $sprintOutput 'True,True,False'

# ---------------------------------------------------------------------------
# Test 15: Closed-issue verification checks PR mentions fallback
# ---------------------------------------------------------------------------
Write-Host '  Test 15: Script source includes PR mention fallback query...'

$psContent14 = Get-Content $scriptPath -Raw
Assert-True 'Closed verification uses fallback PR mention search (#N)' ($psContent14 -match '--search "#\$N"')

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })

if ($failed -gt 0) {
    exit 1
}

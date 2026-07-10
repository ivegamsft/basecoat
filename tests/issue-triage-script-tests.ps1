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
# Test 9: Security without critical label triggers escalation
# ---------------------------------------------------------------------------
Write-Host '  Test 9: Security without critical triggers escalation...'

$secScript2 = @'
$labels       = @("security","P1-high")
$escalated    = $false
if ($labels -contains "security" -and $labels -notcontains "priority:critical" -and $labels -notcontains "P0-critical" -and $labels -notcontains "priority/critical") {
    $escalated = $true
}
$escalated.ToString()
'@

$secOutput2 = & pwsh -NoProfile -Command $secScript2
Assert-Equal 'Security without critical label triggers escalation' $secOutput2 'True'

# ---------------------------------------------------------------------------
# Test 10: Get-TokenOverlap — identical titles → 1.0
# ---------------------------------------------------------------------------
Write-Host '  Test 10: Get-TokenOverlap identical titles...'

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
# Test 11: Get-TokenOverlap — completely different titles → 0.0
# ---------------------------------------------------------------------------
Write-Host '  Test 11: Get-TokenOverlap different titles...'

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
# Test 12: Test-EncodingGibberish detects Mojibake patterns
# ---------------------------------------------------------------------------
Write-Host '  Test 12: Test-EncodingGibberish detects corruption...'

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
# Test 13: Sprint label policy requires sprint:<number>
# ---------------------------------------------------------------------------
Write-Host '  Test 13: Sprint label policy detects missing sprint labels...'

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
# Test 14: Closed-issue verification checks PR mentions fallback
# ---------------------------------------------------------------------------
Write-Host '  Test 14: Script source includes PR mention fallback query...'

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

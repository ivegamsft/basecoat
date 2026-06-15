#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automated GitHub issue triage script for BaseCoat repositories.

.DESCRIPTION
    Runs all 9 triage checks against open and recently closed issues:
      1. Validity (gibberish/spam detection, reopen valid closed issues)
      2. Duplicate detection (>80% keyword overlap)
      3. Closed issue verification (confirm resolution evidence)
      4. Label and type enforcement
      5. Title quality
      6. Proposed fixes and related linkage
      7. Relationship audit
      8. Branch connection check
      9. Priority review

.PARAMETER Repo
    Target repository in "owner/repo" format. Defaults to current git remote.

.PARAMETER Scope
    Which issues to scan: "open", "closed", or "all". Default: "open".

.PARAMETER IssueNumber
    If provided, triage only this specific issue number.

.PARAMETER DryRun
    Preview all actions without writing to GitHub.

.PARAMETER Limit
    Maximum number of issues to fetch. Default: 100.

.EXAMPLE
    pwsh triage-issues.ps1
    pwsh triage-issues.ps1 -Repo "myorg/myrepo" -Scope all -DryRun
    pwsh triage-issues.ps1 -IssueNumber 245
#>

[CmdletBinding()]
param(
    [string] $Repo = "",
    [ValidateSet("open", "closed", "all")]
    [string] $Scope = "open",
    [int]    $IssueNumber = 0,
    [switch] $DryRun,
    [int]    $Limit = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Invoke-GH {
    param([string[]] $Args)
    if ($DryRun -and ($Args[0] -in "issue","pr") -and ($Args[1] -in "edit","close","reopen","comment")) {
        Write-Host "[DRY-RUN] gh $($Args -join ' ')" -ForegroundColor Cyan
        return $null
    }
    $result = gh @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "gh $($Args -join ' ') failed: $result"
        return $null
    }
    return $result
}

function Get-IssueJSON {
    param([int] $N)
    $json = gh issue view $N --repo $Script:Repo --json number,title,body,labels,state,closedAt,createdAt,assignees,comments 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return $json | ConvertFrom-Json
}

function Get-LabelNames {
    param($issue)
    return @($issue.labels | ForEach-Object { $_.name })
}

function Has-Label {
    param($issue, [string] $label)
    return (Get-LabelNames $issue) -contains $label
}

function Has-SprintLabel {
    param([string[]] $labels)
    return (@($labels | Where-Object { $_ -match '^sprint[:/\-]?\d+$' }).Count -gt 0)
}

function Add-Label {
    param([int] $N, [string] $label, [string] $reason)
    Write-Host "  [+label] #$N ← $label ($reason)" -ForegroundColor Yellow
    Invoke-GH "issue","edit",$N,"--repo",$Script:Repo,"--add-label",$label | Out-Null
    $Script:ActionLog += [PSCustomObject]@{ Issue="#$N"; Action="Add label: $label"; Reason=$reason }
}

function Remove-LabelFromIssue {
    param([int] $N, [string] $label, [string] $reason)
    Write-Host "  [-label] #$N ← remove $label ($reason)" -ForegroundColor DarkYellow
    Invoke-GH "issue","edit",$N,"--repo",$Script:Repo,"--remove-label",$label | Out-Null
    $Script:ActionLog += [PSCustomObject]@{ Issue="#$N"; Action="Remove label: $label"; Reason=$reason }
}

function Post-Comment {
    param([int] $N, [string] $body, [string] $reason)
    Write-Host "  [comment] #$N — $reason" -ForegroundColor Cyan
    Invoke-GH "issue","comment",$N,"--repo",$Script:Repo,"--body",$body | Out-Null
    $Script:ActionLog += [PSCustomObject]@{ Issue="#$N"; Action="Comment"; Reason=$reason }
}

function Close-Issue {
    param([int] $N, [string] $reason, [string] $comment)
    Write-Host "  [close] #$N — $reason" -ForegroundColor Red
    if ($comment) { Post-Comment $N $comment $reason }
    Invoke-GH "issue","close",$N,"--repo",$Script:Repo | Out-Null
    $Script:ActionLog += [PSCustomObject]@{ Issue="#$N"; Action="Close"; Reason=$reason }
}

function Reopen-Issue {
    param([int] $N, [string] $reason, [string] $comment)
    Write-Host "  [reopen] #$N — $reason" -ForegroundColor Green
    if ($comment) { Post-Comment $N $comment $reason }
    Invoke-GH "issue","reopen",$N,"--repo",$Script:Repo | Out-Null
    $Script:ActionLog += [PSCustomObject]@{ Issue="#$N"; Action="Reopen"; Reason=$reason }
}

function Flag-ForHumanReview {
    param([int] $N, [string] $reason)
    Write-Host "  [flag] #$N → needs human review: $reason" -ForegroundColor Magenta
    $Script:HumanReview += [PSCustomObject]@{ Issue="#$N"; Reason=$reason }
}

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

function Test-EncodingGibberish {
    param([string] $Text)
    if (-not $Text) { return $false }
    $replacementChar = [string][char]0xFFFD
    $patterns = @(
        [regex]::Escape($replacementChar), # Unicode replacement character: �
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

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Resolve repo
if (-not $Script:Repo) {
    $Script:Repo = gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>$null
    if (-not $Script:Repo) { throw "Could not determine repo. Pass -Repo 'owner/repo'." }
}

Write-Host "`n=== Issue Triage — $($Script:Repo) ===" -ForegroundColor White
if ($DryRun) { Write-Host "[DRY-RUN MODE — no changes will be written]" -ForegroundColor Cyan }

$Script:ActionLog   = @()
$Script:HumanReview = @()

# Fetch issues
$stateFilter = if ($Scope -eq "all") { "open","closed" } elseif ($Scope -eq "closed") { "closed" } else { "open" }
$allIssues = @()

foreach ($state in $stateFilter) {
    $args = @("issue","list","--repo",$Script:Repo,"--state",$state,"--limit",$Limit,"--json","number,title,body,labels,state,closedAt,createdAt,assignees")
    $batch = gh @args 2>$null | ConvertFrom-Json
    if ($batch) { $allIssues += $batch }
}

# Filter to recent closed (30 days) if scope includes closed
if ($Scope -ne "open") {
    $cutoff = (Get-Date).AddDays(-30)
    $allIssues = $allIssues | Where-Object {
        $_.state -eq "open" -or
        ($_.closedAt -and [datetime]$_.closedAt -gt $cutoff)
    }
}

if ($IssueNumber -gt 0) {
    $allIssues = $allIssues | Where-Object { $_.number -eq $IssueNumber }
    if (-not $allIssues) {
        $allIssues = @(Get-IssueJSON $IssueNumber)
    }
}

Write-Host "Fetched $($allIssues.Count) issues to triage.`n"

$typeLabels     = @("bug","enhancement","documentation","chore","security","question")
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
$badTitles      = @("bug","fix","issue","help","todo","test","asdf","qwerty","untitled","new issue","please fix","broken","error")

foreach ($issue in $allIssues) {
    $N      = $issue.number
    $title  = $issue.title
    $body   = if ($issue.body) { $issue.body } else { "" }
    $labels = @($issue.labels | ForEach-Object { $_.name })
    $isOpen = ($issue.state -eq "OPEN" -or $issue.state -eq "open")

    Write-Host "--- #${N}: $title ---" -ForegroundColor White

    # -----------------------------------------------------------------------
    # Check 1: Validity
    # -----------------------------------------------------------------------
    $isGibberish = ($title.Length -lt 5) -or ($badTitles -contains $title.Trim().ToLower()) -or
                   ($body.Length -lt 20 -and $isOpen)
    $hasEncodingGibberish = Test-EncodingGibberish "$title`n$body"

    if ($hasEncodingGibberish -and $isOpen) {
        Add-Label $N "needs-info" "Possible text encoding corruption (mojibake)"
        Add-Label $N "needs-triage" "Needs clean UTF-8 issue text before triage"
        Post-Comment $N "This issue appears to contain text-encoding corruption (for example: `�`, `Ã`, `Â`, `â€™`, `â€œ`).`n`nPlease edit/repost the title and body using UTF-8-safe text so triage can proceed accurately. This issue is being flagged, not auto-closed." "encoding-gibberish flag"
        continue
    }

    if ($isGibberish -and $isOpen) {
        Close-Issue $N "Invalid: title/body is gibberish or unactionable" `
            "Closing as invalid: the title or body does not contain enough information to act on. Please reopen with a clear description, steps to reproduce, and expected/actual behavior."
        Add-Label $N "invalid" "Issue is unactionable"
        continue
    }

    # Reopen wrongly closed valid issues
    if (-not $isOpen -and $labels -contains "invalid" -and $body.Length -gt 100) {
        $hasRepro = $body -match "(steps to reproduce|reproduce|expected|actual|error|stack trace)"
        if ($hasRepro) {
            Reopen-Issue $N "Reopening: was closed invalid but contains valid reproduction steps" `
                "Reopening: this issue was closed as invalid but contains valid reproduction steps or a clear problem description. Please re-triage."
            Remove-LabelFromIssue $N "invalid" "Issue is valid"
            Add-Label $N "needs-triage" "Needs re-triage after reopen"
        }
    }

    # Missing required fields
    if ($isOpen -and $body.Length -lt 50) {
        Add-Label $N "needs-info" "Body too short"
        Post-Comment $N "This issue needs more detail before it can be triaged:`n- [ ] Description of the problem`n- [ ] Steps to reproduce (for bugs)`n- [ ] Expected vs actual behavior`n- [ ] Environment (OS, version, etc.)" "needs-info comment"
    }

    # -----------------------------------------------------------------------
    # Check 2: Duplicate Detection
    # -----------------------------------------------------------------------
    if ($isOpen) {
        $searchTerms = ($title -replace '[^a-zA-Z0-9 ]', '') -replace '\s+', '+'
        $candidates = gh issue list --repo $Script:Repo --state open --search $searchTerms `
            --json number,title 2>$null | ConvertFrom-Json

        foreach ($candidate in $candidates) {
            if ($candidate.number -eq $N) { continue }
            $overlap = Get-TokenOverlap $title $candidate.title
            if ($overlap -gt 0.80) {
                $canonical = [math]::Min($N, $candidate.number)
                $dup       = [math]::Max($N, $candidate.number)
                if ($dup -eq $N) {
                    foreach ($t in @($labels | Where-Object { $typeLabels -contains $_ })) {
                        Remove-LabelFromIssue $N $t "duplicate/type exclusivity — duplicate is authoritative"
                    }
                    Close-Issue $N "Duplicate of #$canonical (overlap $overlap)" `
                        "Duplicate of #$canonical — closing in favor of the original tracker. All updates should go to #$canonical."
                    Add-Label $N "duplicate" "Token overlap $overlap"
                }
                break
            } elseif ($overlap -gt 0.50) {
                Flag-ForHumanReview $N "Possible duplicate of #$($candidate.number) (overlap $overlap)"
            }
        }
    }

    # -----------------------------------------------------------------------
    # Check 3: Closed Issue Verification
    # -----------------------------------------------------------------------
    if (-not $isOpen -and $issue.closedAt -and $labels -notcontains "wontfix" -and $labels -notcontains "duplicate" -and $labels -notcontains "invalid") {
        $closingPRs = gh pr list --repo $Script:Repo --state merged `
            --search "closes #$N OR fixes #$N OR resolves #$N" `
            --json number,title 2>$null | ConvertFrom-Json

        $mentionedPRs = gh pr list --repo $Script:Repo --state merged `
            --search "#$N" `
            --json number,title 2>$null | ConvertFrom-Json

        if (-not $closingPRs -or $closingPRs.Count -eq 0) {
            if ($mentionedPRs -and $mentionedPRs.Count -gt 0) {
                Add-Label $N "needs-verification" "Merged PR mentions issue but does not use closing keyword"
                Post-Comment $N "A merged pull request appears to reference this issue, but no closing keyword was found. Please backfill explicit linkage using Closes/Fixes/Resolves for this issue number, or add a comment with the delivery PR URL." "missing explicit PR closing linkage"
            } else {
                Reopen-Issue $N "Closed without merged PR or resolution evidence" `
                    "Reopening: no merged pull request was found that closes this issue. If it was resolved another way, please add a comment with the commit or evidence of resolution."
                Add-Label $N "needs-verification" "No linked PR found"
            }
        }
    }

    # -----------------------------------------------------------------------
    # Check 4: Label and Type Enforcement
    # -----------------------------------------------------------------------
    $typeLabelSet = @($labels | Where-Object { $typeLabels -contains $_ })
    $hasType     = $typeLabelSet.Count -gt 0
    $hasDuplicate = $labels -contains "duplicate"
    $hasPriority = ($labels | Where-Object { $priorityLabels -contains $_ }).Count -gt 0

    if ($hasDuplicate -and $hasType) {
        $duplicateAuthoritative = (-not $isOpen) -or ($title -match '(?i)\bduplicate\b') -or ($body -match '(?i)duplicate of #\d+')
        if ($duplicateAuthoritative) {
            foreach ($t in $typeLabelSet) {
                Remove-LabelFromIssue $N $t "duplicate/type exclusivity — keeping duplicate"
            }
            Post-Comment $N "Label cleanup: removed type label(s) because this issue is marked as `duplicate`. `duplicate` and type labels are mutually exclusive." "duplicate/type exclusivity"
            $hasType = $false
        } else {
            Remove-LabelFromIssue $N "duplicate" "duplicate/type exclusivity — keeping type label"
            Post-Comment $N "Label cleanup: removed `duplicate` because this issue has an active type label and is being treated as a normal typed issue." "duplicate/type exclusivity"
            $hasDuplicate = $false
        }
    }

    if (-not $hasType -and $isOpen -and -not $hasDuplicate) {
        $inferredType = $null
        if ($title -match '(?i)(error|crash|fail|broken|regression|wrong|incorrect|not working)' -or $body -match '(?i)(error|exception|stack trace|traceback)') {
            $inferredType = "bug"
        } elseif ($title -match '(?i)(add|support|allow|feature|request|improve|enhance|new)') {
            $inferredType = "enhancement"
        } elseif ($title -match '(?i)(doc|readme|guide|typo|spelling|documentation)') {
            $inferredType = "documentation"
        } elseif ($title -match '(?i)(CVE|vuln|secret|injection|XSS|CSRF|security)' -or $body -match '(?i)(CVE-\d|vulnerability|exploit)') {
            $inferredType = "security"
        } elseif ($title -match '(?i)(refactor|cleanup|debt|upgrade|bump|chore|dependency)') {
            $inferredType = "chore"
        } elseif ($title -match '(?i)(how|why|what|clarify|explain|question|help)') {
            $inferredType = "question"
        }

        if ($inferredType) {
            Add-Label $N $inferredType "Inferred from title/body"
        } else {
            Add-Label $N "needs-triage" "Missing type label — could not infer from title/body"
            Post-Comment $N "This issue is missing a type label. Please apply one of:`n- `bug`n- `enhancement`n- `documentation`n- `chore`n- `security`n- `question`" "missing type label"
        }
    }

    if (-not $hasPriority -and $isOpen -and -not $hasDuplicate) {
        # Security auto-escalate
        if ($labels -contains "security" -or $inferredType -eq "security") {
            Add-Label $N $canonicalPriorityLabels.critical "Security issues are auto-escalated to critical"
            Post-Comment $N "Priority escalated to **critical**: security issues are automatically assigned critical priority per triage policy." "auto-escalate security"
        } else {
            Add-Label $N "needs-triage" "Missing priority label"
        }
    }

    if ($isOpen -and -not $hasDuplicate -and -not (Has-SprintLabel -labels $labels)) {
        Add-Label $N "needs-triage" "Missing sprint label"
        Post-Comment $N "This issue is missing a sprint label. Please add one using the sprint:<number> format (for example, sprint:24) so it can be included in sprint mapping and release-note reporting." "missing sprint label"
    }

    # -----------------------------------------------------------------------
    # Check 5: Title Quality
    # -----------------------------------------------------------------------
    if ($isOpen) {
        $titleLower   = $title.Trim().ToLower()
        $isBadTitle   = ($title.Length -lt 10) -or ($badTitles -contains $titleLower) -or
                        ($title -match '^\s*[a-z]{1,6}\s*$')
        if ($isBadTitle) {
            $suggestedTitle = if ($body.Length -gt 20) {
                # Extract first sentence of body as suggested title
                ($body -split '[.!\n]' | Where-Object { $_.Trim().Length -gt 10 } | Select-Object -First 1).Trim()
            } else { "Please provide a descriptive title" }
            Post-Comment $N "**Title improvement suggested**`n`nThe current title ``$title`` is too generic.`n`nSuggested: ``$suggestedTitle```n`nPlease update the title to help with searchability and sprint planning. The agent will not rename it automatically." "poor title"
        }
    }

    # -----------------------------------------------------------------------
    # Check 7: Relationship Audit (simplified scan)
    # -----------------------------------------------------------------------
    if ($isOpen -and $body -match '#(\d+)') {
        $referencedIssue = $matches[1]
        $hasRelKeyword = $body -match '(?i)(blocked by|depends on|part of|closes|fixes|resolves|duplicate of|related to)'
        if (-not $hasRelKeyword) {
            $relationshipHint = "This issue references issue $referencedIssue without a relationship keyword. Add one of: Blocked by issue $referencedIssue, Depends on issue $referencedIssue, Part of issue $referencedIssue, or Related to issue $referencedIssue."
            Post-Comment $N $relationshipHint "missing relationship keyword"
        }
        if ($body -match '(?i)blocked by #(\d+)') {
            Add-Label $N "blocked" "Blocked by #$($matches[1])"
        }
    }

    # -----------------------------------------------------------------------
    # Check 8: Branch Connection
    # -----------------------------------------------------------------------
    if ($isOpen) {
        $branches = gh api "repos/$($Script:Repo)/branches" --paginate --jq '.[].name' 2>$null
        $matchedBranch = $branches | Where-Object { $_ -match "^(feat|fix|chore|copilot)/($N)-" } | Select-Object -First 1
        if ($matchedBranch) {
            $linkedPR = gh pr list --repo $Script:Repo --head $matchedBranch --json number,state 2>$null | ConvertFrom-Json
            if (-not $linkedPR -or $linkedPR.Count -eq 0) {
                Post-Comment $N "**Open branch found without a linked PR**`n`nBranch ``$matchedBranch`` exists but no pull request is linked to this issue.`n`nTo create one:`n``````bash`ngh pr create --head $matchedBranch --base main --title `"$title`" --body `"Closes #$N`"`n``````" "branch without PR"
            }
        }
    }

    # -----------------------------------------------------------------------
    # Check 9: Priority Review
    # -----------------------------------------------------------------------
    if ($isOpen) {
        $agedays = ([datetime]::UtcNow - [datetime]$issue.createdAt).TotalDays

        if ($agedays -gt 90 -and $labels -notcontains "stale" -and
            -not ($labels | Where-Object { $priorityLabels -contains $_ }) -and
            $labels -notcontains "blocked") {
            Add-Label $N "stale" "Open >90 days with no resolved state"
            Post-Comment $N "This issue has been open for $([math]::Round($agedays)) days with no recent activity. Adding ``stale`` label. If this is still relevant, please comment to keep it active." "stale policy"
        }

        if ($labels -contains "security" -and $labels -notcontains $canonicalPriorityLabels.critical -and $labels -notcontains "P0-critical" -and $labels -notcontains "priority/critical") {
            Add-Label $N $canonicalPriorityLabels.critical "Security issue without critical priority"
        }

        if ($labels -contains "bug" -and $agedays -gt 30 -and
            -not ($labels | Where-Object { $priorityLabels -contains $_ })) {
            Add-Label $N $canonicalPriorityLabels.high "Bug open >30 days without priority"
        }

        if (-not ($labels | Where-Object { $priorityLabels -contains $_ }) -and $isOpen) {
            Add-Label $N $canonicalPriorityLabels.low "No priority set; applying floor"
        }
    }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

$closeCount  = ($Script:ActionLog | Where-Object { $_.Action -eq "Close" }).Count
$reopenCount = ($Script:ActionLog | Where-Object { $_.Action -eq "Reopen" }).Count
$labelCount  = ($Script:ActionLog | Where-Object { $_.Action -like "Add label*" }).Count
$commentCount= ($Script:ActionLog | Where-Object { $_.Action -eq "Comment" }).Count

Write-Host "`n=== Triage Report ===" -ForegroundColor White
Write-Host "Issues scanned  : $($allIssues.Count)"
Write-Host "Actions taken   : $($Script:ActionLog.Count)"
Write-Host "Closed          : $closeCount"
Write-Host "Reopened        : $reopenCount"
Write-Host "Labels applied  : $labelCount"
Write-Host "Comments posted : $commentCount"
Write-Host "Human review    : $($Script:HumanReview.Count)"

if ($Script:HumanReview.Count -gt 0) {
    Write-Host "`n--- Needs Human Review ---" -ForegroundColor Magenta
    $Script:HumanReview | ForEach-Object { Write-Host "  $($_.Issue) — $($_.Reason)" }
}

if ($Script:ActionLog.Count -gt 0) {
    Write-Host "`n--- Actions Log ---" -ForegroundColor Yellow
    $Script:ActionLog | Format-Table -AutoSize
}

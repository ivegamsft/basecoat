<#
.SYNOPSIS
    Audits GitHub Project automation rules for drift against the canonical AIDL guardrail baseline.

.DESCRIPTION
    Compares live GitHub Project (v2) automation rules to the baseline manifest and
    classifies each delta by severity. Supports advisory mode (report only) and enforce
    mode (open GitHub issues for findings at or above the severity threshold).

.PARAMETER Repo
    Repository in owner/repo format. Defaults to the current repo from git remote.

.PARAMETER ProjectId
    GitHub Project (v2) node ID (PVT_...). Mutually exclusive with ProjectUrl.

.PARAMETER ProjectUrl
    GitHub Project URL. Used to resolve the project node ID when ProjectId is not provided.

.PARAMETER BaselinePath
    Path to the baseline manifest JSON. Defaults to scripts/project-rules-baseline.json.

.PARAMETER Mode
    Execution mode: advisory (report only) or enforce (open remediation issues).
    Default: advisory.

.PARAMETER SeverityThreshold
    Minimum severity to include in output and, in enforce mode, to open issues for.
    Accepted values: critical, high, medium, low. Default: low.

.PARAMETER OutputPath
    Path to write the JSON drift report. Defaults to drift-report.json in the current directory.

.PARAMETER AssumeYes
    Skip interactive confirmation prompts. For use in CI.

.EXAMPLE
    pwsh scripts/project-rules-drift-audit.ps1 -Repo "myorg/myrepo" -Mode advisory

.EXAMPLE
    pwsh scripts/project-rules-drift-audit.ps1 -Repo "myorg/myrepo" -Mode enforce -SeverityThreshold high -AssumeYes

.NOTES
    Requires the GitHub CLI (gh) authenticated with a token that has read:project and issues:write scopes.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Repo,
    [string]$ProjectId,
    [string]$ProjectUrl,
    [string]$BaselinePath = (Join-Path $PSScriptRoot 'project-rules-baseline.json'),
    [ValidateSet('advisory', 'enforce')]
    [string]$Mode = 'advisory',
    [ValidateSet('critical', 'high', 'medium', 'low')]
    [string]$SeverityThreshold = 'low',
    [string]$OutputPath = (Join-Path (Get-Location) 'drift-report.json'),
    [switch]$AssumeYes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SeverityOrder = @{ critical = 0; high = 1; medium = 2; low = 3 }

function Write-AuditLog {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ' -AsUTC
    Write-Host "[$timestamp] [$Level] $Message"
}

function Resolve-Repo {
    if ($Repo) { return $Repo }
    $remote = git remote get-url origin 2>$null
    if ($remote -match 'github\.com[:/](.+?)(?:\.git)?$') {
        return $Matches[1]
    }
    throw "Cannot resolve repository. Provide -Repo or run from a GitHub-backed git repo."
}

function Resolve-ProjectId {
    param([string]$RepoName)

    if ($ProjectId) { return $ProjectId }

    if ($ProjectUrl) {
        # Extract project number from URL and resolve node ID
        if ($ProjectUrl -match '/projects/(\d+)') {
            $projectNumber = [int]$Matches[1]
            $ownerParts = $RepoName.Split('/')
            $query = @"
query {
  repositoryOwner(login: "$($ownerParts[0])") {
    projectV2(number: $projectNumber) {
      id
    }
  }
}
"@
            $stdout = $query | gh api graphql --input - 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to resolve project ID from URL: $ProjectUrl"
            }
            $result = $stdout | ConvertFrom-Json
            return $result.data.repositoryOwner.projectV2.id
        }
        throw "Cannot parse project number from URL: $ProjectUrl"
    }

    # Baseline-only mode: no project specified; live comparison will be skipped.
    Write-AuditLog INFO "No -ProjectId or -ProjectUrl provided. Running in baseline-only validation mode."
    return $null
}

function Get-LiveProjectRules {
    param([string]$ProjId)

    $query = @"
query {
  node(id: "$ProjId") {
    ... on ProjectV2 {
      id
      title
      workflows(first: 100) {
        nodes {
          id
          name
          enabled
          triggers {
            type
            ... on ProjectV2WorkflowAutoArchiveTrigger { archiveWhen }
            ... on ProjectV2WorkflowAutoAddTrigger { addWhen }
            ... on ProjectV2WorkflowAutoSetFieldTrigger { field { name } value }
            ... on ProjectV2WorkflowPullRequestTrigger { pullRequestEvent }
            ... on ProjectV2WorkflowIssuesTrigger { issueEvent }
            ... on ProjectV2WorkflowLabelTrigger { label { name } }
          }
          actions {
            type
            ... on ProjectV2WorkflowSetFieldAction { field { name } value }
            ... on ProjectV2WorkflowArchiveAction { archived }
            ... on ProjectV2WorkflowAddToProjectAction { dummy: __typename }
          }
        }
      }
    }
  }
}
"@
    Write-AuditLog INFO "Fetching live project rules for project $ProjId..."
    $stderr = $null
    $stdout = $query | gh api graphql --input - 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "GraphQL request failed (exit code $LASTEXITCODE). Check GH_TOKEN scope (read:project required)."
    }
    $result = $stdout | ConvertFrom-Json
    if ($result.errors) {
        Write-AuditLog WARN "GraphQL errors encountered: $($result.errors | ConvertTo-Json -Compress)"
    }
    return $result.data.node
}

function Compare-Rules {
    param(
        [array]$BaselineRules,
        [object]$LiveProject
    )

    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()
    $liveWorkflows = if ($LiveProject.workflows.nodes) { $LiveProject.workflows.nodes } else { @() }

    foreach ($rule in $BaselineRules) {
        $matched = $liveWorkflows | Where-Object { $_.name -ieq $rule.name } | Select-Object -First 1

        if (-not $matched) {
            $findings.Add([PSCustomObject]@{
                finding_id     = "$($rule.rule_id)-missing"
                rule_id        = $rule.rule_id
                rule_name      = $rule.name
                drift_type     = 'missing'
                severity       = $rule.severity_if_missing
                baseline_value = @{
                    enabled   = $rule.enabled
                    condition = $rule.condition
                    action    = $rule.action
                }
                live_value     = $null
                remediation    = "Add automation rule '$($rule.name)'. Condition: $($rule.condition | ConvertTo-Json -Compress). Action: $($rule.action | ConvertTo-Json -Compress)."
                effort         = 'minutes'
                rationale      = $rule.rationale
            })
            continue
        }

        # Check enabled state drift — use severity_if_missing when a required rule is disabled
        if ($rule.enabled -ne $matched.enabled) {
            $enabledSeverity = if ($rule.enabled -and -not $matched.enabled) {
                $rule.severity_if_missing
            } else {
                'medium'
            }
            $findings.Add([PSCustomObject]@{
                finding_id     = "$($rule.rule_id)-modified-enabled"
                rule_id        = $rule.rule_id
                rule_name      = $rule.name
                drift_type     = 'modified'
                severity       = $enabledSeverity
                baseline_value = @{ enabled = $rule.enabled }
                live_value     = @{ enabled = $matched.enabled }
                remediation    = "Set rule '$($rule.name)' enabled=$($rule.enabled)."
                effort         = 'minutes'
                rationale      = $rule.rationale
            })
        }

        # Note: condition/action drift detection is deferred.
        # The GraphQL response shape (triggers[]/actions[]) differs from the baseline manifest
        # shape (condition{}/action{}), so a raw JSON comparison produces false positives on
        # every rule. Deep normalization is tracked as a future enhancement.
    }

    # Report extra rules not in baseline — use unique rule_id per extra rule for determinism
    foreach ($liveRule in $liveWorkflows) {
        $inBaseline = $BaselineRules | Where-Object { $_.name -ieq $liveRule.name }
        if (-not $inBaseline) {
            $safeRuleId = "EXTRA-$($liveRule.name -replace '[^a-zA-Z0-9]', '-')"
            $findings.Add([PSCustomObject]@{
                finding_id     = "$safeRuleId-extra"
                rule_id        = $safeRuleId
                rule_name      = $liveRule.name
                drift_type     = 'extra'
                severity       = 'low'
                baseline_value = $null
                live_value     = @{
                    enabled = $liveRule.enabled
                    name    = $liveRule.name
                }
                remediation    = "Rule '$($liveRule.name)' is not in the baseline. Review and either add it to the baseline or remove it from the project."
                effort         = 'minutes'
                rationale      = 'Extra rules outside the guardrail baseline may introduce unintended board behavior.'
            })
        }
    }

    return $findings
}

function Get-SeveritySummary {
    param([System.Collections.Generic.List[PSCustomObject]]$Findings)
    $summary = @{ critical = 0; high = 0; medium = 0; low = 0 }
    foreach ($f in $Findings) { $summary[$f.severity]++ }
    return $summary
}

function Open-RemediationIssue {
    param(
        [string]$RepoName,
        [PSCustomObject]$Finding
    )

    $title = "Project rules drift: [$($Finding.severity.ToUpper())] $($Finding.rule_name) ($($Finding.drift_type))"
    $body = @"
## Project Rules Drift Finding

**Finding ID:** $($Finding.finding_id)
**Rule:** $($Finding.rule_name) (``$($Finding.rule_id)``)
**Drift type:** $($Finding.drift_type)
**Severity:** $($Finding.severity)

### Evidence

| | Value |
|---|---|
| **Baseline** | ``$($Finding.baseline_value | ConvertTo-Json -Compress)`` |
| **Live** | ``$($Finding.live_value | ConvertTo-Json -Compress)`` |

### Remediation

$($Finding.remediation)

**Estimated effort:** $($Finding.effort)

**Rationale:** $($Finding.rationale)

---
_Generated by project-rules-drift-audit script. Resolve this finding to restore guardrail compliance._
"@

    $existingIssues = gh issue list --repo $RepoName --label "project-rules-drift" --state open --json number,title | ConvertFrom-Json
    $duplicate = $existingIssues | Where-Object { $_.title -eq $title }
    if ($duplicate) {
        Write-AuditLog INFO "Issue already open for finding $($Finding.finding_id) — skipping."
        return
    }

    Write-AuditLog INFO "Opening issue for finding $($Finding.finding_id)..."
    gh issue create `
        --repo $RepoName `
        --title $title `
        --body $body `
        --label "project-rules-drift" `
        --label "governance" `
        | Out-Null
}

function Format-MarkdownSummary {
    param(
        [string]$RepoName,
        [string]$ProjId,
        [object]$Baseline,
        [string]$AuditMode,
        [System.Collections.Generic.List[PSCustomObject]]$Findings,
        [hashtable]$Summary
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("## Project Rules Drift Audit -- $RepoName")
    $lines.Add("")
    $lines.Add("**Project:** $ProjId")
    $lines.Add("**Baseline:** v$($Baseline.version)")
    $lines.Add("**Mode:** $AuditMode")
    $totalFindings = $Findings.Count
    $lines.Add("**Findings:** $totalFindings (critical: $($Summary.critical), high: $($Summary.high), medium: $($Summary.medium), low: $($Summary.low))")
    $lines.Add("")

    if ($totalFindings -eq 0) {
        $lines.Add("No drift detected. All project rules match the baseline.")
    } else {
        $lines.Add("| Finding ID | Rule | Drift Type | Severity | Remediation |")
        $lines.Add("|---|---|---|---|---|")
        foreach ($f in ($Findings | Sort-Object { $SeverityOrder[$_.severity] }, rule_id)) {
            $lines.Add("| $($f.finding_id) | $($f.rule_name) | $($f.drift_type) | $($f.severity) | $($f.remediation) |")
        }
    }
    return $lines -join "`n"
}

# ---- Main ----

Write-AuditLog INFO "Project Rules Drift Audit starting. Mode=$Mode, Threshold=$SeverityThreshold"

if (-not (Test-Path $BaselinePath)) {
    throw "Baseline manifest not found at: $BaselinePath"
}

$baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
Write-AuditLog INFO "Loaded baseline v$($baseline.version) with $($baseline.rules.Count) rules."

$repoName = Resolve-Repo
$projId = Resolve-ProjectId -RepoName $repoName

$allFindings = [System.Collections.Generic.List[PSCustomObject]]::new()

if ($projId) {
    $liveProject = Get-LiveProjectRules -ProjId $projId
    Write-AuditLog INFO "Fetched live project '$($liveProject.title)'."
    $compareResults = Compare-Rules -BaselineRules $baseline.rules -LiveProject $liveProject
    foreach ($f in $compareResults) { $allFindings.Add($f) }
} else {
    Write-AuditLog INFO "Baseline-only mode: skipping live project comparison."
}

# Filter by severity threshold
$thresholdIndex = $SeverityOrder[$SeverityThreshold]
$filteredFindings = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($f in ($allFindings | Where-Object { $SeverityOrder[$_.severity] -le $thresholdIndex })) {
    $filteredFindings.Add($f)
}

$summary = Get-SeveritySummary -Findings $filteredFindings

$auditId = "$(Get-Date -Format 'yyyyMMddHHmmss')-$($repoName.Replace('/', '-'))"
$projectTitle = if ($projId -and $liveProject) { $liveProject.title } else { '(baseline-only)' }

$report = [PSCustomObject]@{
    audit_id         = $auditId
    repo             = $repoName
    project_id       = if ($projId) { $projId } else { $null }
    project_title    = $projectTitle
    baseline_version = $baseline.version
    mode             = $Mode
    severity_filter  = $SeverityThreshold
    generated_at     = (Get-Date -Format 'o' -AsUTC)
    findings         = @($filteredFindings | Sort-Object { $SeverityOrder[$_.severity] }, rule_id)
    summary          = [PSCustomObject]@{
        total_findings = $filteredFindings.Count
        by_severity    = [PSCustomObject]$summary
        by_drift_type  = [PSCustomObject]@{
            missing  = ($filteredFindings | Where-Object drift_type -eq 'missing').Count
            modified = ($filteredFindings | Where-Object drift_type -eq 'modified').Count
            extra    = ($filteredFindings | Where-Object drift_type -eq 'extra').Count
        }
    }
}

# Write JSON report
$report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding utf8
Write-AuditLog INFO "JSON report written to $OutputPath"

# Write Markdown summary
$markdown = Format-MarkdownSummary `
    -RepoName $repoName `
    -ProjId (if ($projId) { $projId } else { '(baseline-only)' }) `
    -Baseline $baseline `
    -AuditMode $Mode `
    -Findings $filteredFindings `
    -Summary $summary

Write-Host ""
Write-Host $markdown
Write-Host ""

# Open issues in enforce mode
if ($Mode -eq 'enforce') {
    $actionableFindings = $filteredFindings | Where-Object { $SeverityOrder[$_.severity] -le $SeverityOrder[$SeverityThreshold] }
    if ($actionableFindings.Count -eq 0) {
        Write-AuditLog INFO "Enforce mode: no findings at or above '$SeverityThreshold'. No issues opened."
    } else {
        if (-not $AssumeYes) {
            Write-Host "Enforce mode will open $($actionableFindings.Count) GitHub issue(s) in $repoName."
            $confirm = Read-Host "Continue? [y/N]"
            if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                Write-AuditLog INFO "Aborted by user."
                exit 0
            }
        }
        foreach ($finding in $actionableFindings) {
            Open-RemediationIssue -RepoName $repoName -Finding $finding
        }
    }
}

# Write step summary for CI (guarded — $env:GITHUB_STEP_SUMMARY is unset in local runs)
if ($env:GITHUB_STEP_SUMMARY) {
    $driftStatus = if ($summary.critical -gt 0) { 'critical' } elseif ($summary.high -gt 0) { 'high' } elseif ($summary.medium -gt 0) { 'medium' } else { 'clean' }
    $summaryLines = @(
        "### Drift Audit Summary",
        "",
        "**Status:** $driftStatus",
        "**Findings:** $($filteredFindings.Count) (critical: $($summary.critical), high: $($summary.high), medium: $($summary.medium), low: $($summary.low))",
        "**Mode:** $Mode",
        "**Baseline:** v$($baseline.version)"
    )
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value ($summaryLines -join "`n")
}

Write-AuditLog INFO "Audit complete. Total findings: $($filteredFindings.Count) (critical=$($summary.critical), high=$($summary.high), medium=$($summary.medium), low=$($summary.low))"

if ($summary.critical -gt 0) {
    Write-AuditLog WARN "Critical drift detected. Immediate remediation required."
    exit 2
}
if ($summary.high -gt 0) {
    Write-AuditLog WARN "High-severity drift detected."
    exit 1
}
exit 0

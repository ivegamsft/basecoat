<#
.SYNOPSIS
    Validates intake contract readiness in a downstream consumer repository.

.DESCRIPTION
    Checks whether a GitHub repository satisfies the BaseCoat intake contract
    minimum surfaces:
      - .github/PULL_REQUEST_TEMPLATE.md is present
      - At least one issue template exists under .github/ISSUE_TEMPLATE/ or
        a legacy .github/ISSUE_TEMPLATE.md

    Optionally checks for the presence of key BaseCoat-delivered workflows
    (prd-spec-gate, intake-contract-check) when -CheckWorkflows is specified.

    Exits 0 when all checks pass; exits 1 when any required surface is missing.

.PARAMETER Repo
    Full GitHub repository slug (owner/name). Required.

.PARAMETER CheckWorkflows
    Also verify that the prd-spec-gate and intake-contract-check workflows are
    installed in the consumer repo.

.PARAMETER OutputFormat
    Output format: 'text' (default, human-readable) or 'json' (machine-readable).

.EXAMPLE
    pwsh scripts/validate-intake-contract.ps1 -Repo IBuySpy-Dev/wawkr

.EXAMPLE
    pwsh scripts/validate-intake-contract.ps1 -Repo IBuySpy-Dev/wawkr -CheckWorkflows

.EXAMPLE
    pwsh scripts/validate-intake-contract.ps1 -Repo IBuySpy-Dev/wawkr -OutputFormat json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [switch]$CheckWorkflows,

    [ValidateSet('text', 'json')]
    [string]$OutputFormat = 'text'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Result([string]$Status, [string]$Check, [string]$Detail) {
    if ($OutputFormat -eq 'text') {
        $icon = switch ($Status) {
            'pass' { '✓' }
            'fail' { '✗' }
            'warn' { '!' }
            default { '?' }
        }
        $color = switch ($Status) {
            'pass' { 'Green' }
            'fail' { 'Red' }
            'warn' { 'Yellow' }
            default { 'White' }
        }
        Write-Host ("  [{0}] {1,-45} {2}" -f $icon, $Check, $Detail) -ForegroundColor $color
    }
}

function Test-GitHubPath([string]$Repo, [string]$Path) {
    $response = gh api "repos/$Repo/contents/$Path" --silent 2>&1
    return $LASTEXITCODE -eq 0
}

function Get-GitHubDirectoryCount([string]$Repo, [string]$Dir) {
    $response = gh api "repos/$Repo/contents/$Dir" 2>&1
    if ($LASTEXITCODE -ne 0) { return 0 }
    try {
        $items = $response | ConvertFrom-Json
        $count = @($items | Where-Object {
            $_.type -eq 'file' -and ($_.name -match '\.(md|yml|yaml)$')
        }).Count
        return $count
    } catch {
        return 0
    }
}

# Validate gh CLI is available and authenticated
$ghVersion = gh --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "gh CLI is not installed or not on PATH. Install it from https://cli.github.com/"
    exit 1
}

if ($OutputFormat -eq 'text') {
    Write-Host ""
    Write-Host "Intake Contract Validation: $Repo" -ForegroundColor Cyan
    Write-Host ("=" * 60)
    Write-Host ""
}

$results = [System.Collections.Generic.List[pscustomobject]]::new()
$failCount = 0

# ── Check 1: PR template ────────────────────────────────────────────────────
$prTemplatePath = '.github/PULL_REQUEST_TEMPLATE.md'
$prTemplatePresent = Test-GitHubPath -Repo $Repo -Path $prTemplatePath
$prStatus = if ($prTemplatePresent) { 'pass' } else { 'fail' }
if (-not $prTemplatePresent) { $failCount++ }

Write-Result -Status $prStatus -Check 'PR template' -Detail $(
    if ($prTemplatePresent) { "Found: $prTemplatePath" } else { "Missing: $prTemplatePath" }
)
$results.Add([pscustomobject]@{
    check   = 'pr_template'
    status  = $prStatus
    detail  = if ($prTemplatePresent) { "found: $prTemplatePath" } else { "missing: $prTemplatePath" }
})

# ── Check 2: Issue templates ─────────────────────────────────────────────────
$issueTemplateDir = '.github/ISSUE_TEMPLATE'
$legacyIssueTemplate = '.github/ISSUE_TEMPLATE.md'
$issueCount = Get-GitHubDirectoryCount -Repo $Repo -Dir $issueTemplateDir
$legacyPresent = $false
if ($issueCount -eq 0) {
    $legacyPresent = Test-GitHubPath -Repo $Repo -Path $legacyIssueTemplate
}
$hasIssueTemplates = $issueCount -gt 0 -or $legacyPresent
$issueStatus = if ($hasIssueTemplates) { 'pass' } else { 'fail' }
if (-not $hasIssueTemplates) { $failCount++ }

$issueDetail = if ($issueCount -gt 0) {
    "Found $issueCount template(s) in $issueTemplateDir"
} elseif ($legacyPresent) {
    "Found legacy: $legacyIssueTemplate"
} else {
    "Missing: $issueTemplateDir/ and $legacyIssueTemplate"
}

Write-Result -Status $issueStatus -Check 'Issue template(s)' -Detail $issueDetail
$results.Add([pscustomobject]@{
    check   = 'issue_templates'
    status  = $issueStatus
    detail  = $issueDetail
})

# ── Check 3 (optional): Workflow presence ────────────────────────────────────
if ($CheckWorkflows) {
    $workflowsToCheck = @(
        @{ name = 'prd-spec-gate';               paths = @('basecoat-prd-spec-gate.yml', 'prd-spec-gate.yml') }
        @{ name = 'intake-contract-check';       paths = @('basecoat-intake-contract-check.yml', 'intake-contract-check.yml') }
    )

    foreach ($wf in $workflowsToCheck) {
        $found = $false
        $foundPath = ''
        foreach ($p in $wf.paths) {
            $wfPath = ".github/workflows/$p"
            if (Test-GitHubPath -Repo $Repo -Path $wfPath) {
                $found = $true
                $foundPath = $wfPath
                break
            }
        }
        $wfStatus = if ($found) { 'pass' } else { 'warn' }
        Write-Result -Status $wfStatus -Check "Workflow: $($wf.name)" -Detail $(
            if ($found) { "Found: $foundPath" } else { "Not installed (optional)" }
        )
        $results.Add([pscustomobject]@{
            check   = "workflow_$($wf.name -replace '-','_')"
            status  = $wfStatus
            detail  = if ($found) { "found: $foundPath" } else { "not installed" }
        })
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
$overallStatus = if ($failCount -eq 0) { 'pass' } else { 'fail' }

if ($OutputFormat -eq 'text') {
    Write-Host ""
    Write-Host ("─" * 60)
    if ($failCount -eq 0) {
        Write-Host "Result: PASS — $Repo satisfies the BaseCoat intake contract." -ForegroundColor Green
    } else {
        Write-Host "Result: FAIL — $failCount required surface(s) missing in $Repo." -ForegroundColor Red
        Write-Host ""
        Write-Host "Recommended next steps:" -ForegroundColor Yellow
        Write-Host "  1. Add missing templates from docs/templates/ or BaseCoat reference copies."
        Write-Host "  2. Run 'pwsh scripts/configure-downstream-workflows.ps1 -IncludeTemplates' in"
        Write-Host "     the consumer repo to install BaseCoat-managed workflows."
        Write-Host "  3. Re-run this script to confirm all checks pass."
    }
    Write-Host ""
} elseif ($OutputFormat -eq 'json') {
    @{
        repo    = $Repo
        status  = $overallStatus
        checks  = $results
    } | ConvertTo-Json -Depth 3
}

exit $(if ($failCount -eq 0) { 0 } else { 1 })

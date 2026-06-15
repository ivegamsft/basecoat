param(
    [ValidateSet('audit', 'enforce')]
    [string]$Mode = 'audit',
    [string]$SummaryPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Add-Finding {
    param(
        [string]$Id,
        [string]$Severity,
        [string]$File,
        [string]$Message,
        [string]$Recommendation
    )

    $script:findings += [pscustomobject]@{
        id             = $Id
        severity       = $Severity
        file           = $File
        message        = $Message
        recommendation = $Recommendation
    }
}

function Get-SectionLabels {
    param(
        [string]$Content,
        [string]$SectionHeader
    )

    $pattern = "(?ms)###\s+$([regex]::Escape($SectionHeader))\s*\r?\n(?<body>.*?)(?:\r?\n###\s+|\r?\n##\s+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return @()
    }

    $labels = [regex]::Matches($match.Groups['body'].Value, '(?m)^\s*-\s*`([^`]+)`') |
        ForEach-Object { $_.Groups[1].Value.Trim() } |
        Where-Object { $_ -ne '' }

    return @($labels)
}

function New-FollowUpIssueLink {
    param(
        [string]$Title,
        [string]$Body
    )

    if (-not $env:GITHUB_SERVER_URL -or -not $env:GITHUB_REPOSITORY) {
        return ''
    }

    $titleEscaped = [System.Uri]::EscapeDataString($Title)
    $bodyEscaped = [System.Uri]::EscapeDataString($Body)
    return "$($env:GITHUB_SERVER_URL)/$($env:GITHUB_REPOSITORY)/issues/new?title=$titleEscaped&body=$bodyEscaped"
}

$findings = @()

$governanceContractPath = Join-Path $repoRoot 'docs/reference/governance-contract.md'
$labelTaxonomyPath = Join-Path $repoRoot 'docs/reference/label-taxonomy.md'
$issueTemplatePath = Join-Path $repoRoot '.github/ISSUE_TEMPLATE/issue.md'
$pullRequestTemplatePath = Join-Path $repoRoot '.github/PULL_REQUEST_TEMPLATE.md'
$issueTriageWorkflowPath = Join-Path $repoRoot '.github/workflows/issue-triage.md'
$governanceGuidePath = Join-Path $repoRoot 'docs/reference/governance.md'

$requiredFiles = @(
    $governanceContractPath,
    $labelTaxonomyPath,
    $issueTemplatePath,
    $pullRequestTemplatePath,
    $issueTriageWorkflowPath,
    $governanceGuidePath
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Add-Finding -Id 'META-001' -Severity 'critical' -File $file -Message 'Required governance metadata file is missing.' -Recommendation 'Restore the file or update governance workflow scope.'
    }
}

if ($findings.Count -gt 0) {
    $reportHeader = "# Governance Metadata Drift Report`n`nMode: **$Mode**`n"
    $reportBody = $findings | ForEach-Object { "- [$($_.severity)] $($_.file): $($_.message) -- $($_.recommendation)" }
    $report = $reportHeader + "`n" + ($reportBody -join "`n") + "`n"
    Write-Host $report
    if ($SummaryPath) {
        Set-Content -Path $SummaryPath -Value $report -Encoding UTF8
    }
    if ($env:GITHUB_STEP_SUMMARY) {
        Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $report
    }
    exit 1
}

$governanceContract = Get-Content $governanceContractPath -Raw
$labelTaxonomy = Get-Content $labelTaxonomyPath -Raw
$issueTemplate = Get-Content $issueTemplatePath -Raw
$pullRequestTemplate = Get-Content $pullRequestTemplatePath -Raw
$issueTriageWorkflow = Get-Content $issueTriageWorkflowPath -Raw
$governanceGuide = Get-Content $governanceGuidePath -Raw

$issueTypeLabels = Get-SectionLabels -Content $governanceContract -SectionHeader 'Issue types'
$priorityLabels = Get-SectionLabels -Content $governanceContract -SectionHeader 'Priorities'
$stateRoutingLabels = Get-SectionLabels -Content $governanceContract -SectionHeader 'State and routing labels'
$assetLabels = Get-SectionLabels -Content $governanceContract -SectionHeader 'Asset labels'

if ($issueTypeLabels.Count -eq 0 -or $priorityLabels.Count -eq 0) {
    Add-Finding -Id 'META-002' -Severity 'critical' -File 'docs/reference/governance-contract.md' -Message 'Canonical issue type or priority labels could not be parsed.' -Recommendation 'Restore bullet-based label lists in governance contract sections.'
}

if ($pullRequestTemplate -notmatch 'docs/reference/governance-contract\.md') {
    Add-Finding -Id 'META-003' -Severity 'high' -File '.github/PULL_REQUEST_TEMPLATE.md' -Message 'PR template is missing governance contract reference.' -Recommendation 'Add `docs/reference/governance-contract.md` reference in PR template governance section.'
}

if ($issueTemplate -notmatch 'docs/reference/governance-contract\.md') {
    Add-Finding -Id 'META-004' -Severity 'high' -File '.github/ISSUE_TEMPLATE/issue.md' -Message 'Issue template is missing governance contract reference.' -Recommendation 'Add governance contract reference link in the issue template.'
}

if ($governanceGuide -notmatch 'docs/reference/label-taxonomy\.md') {
    Add-Finding -Id 'META-005' -Severity 'medium' -File 'docs/reference/governance.md' -Message 'Governance guide does not reference label taxonomy.' -Recommendation 'Add `docs/reference/label-taxonomy.md` to related references.'
}

foreach ($label in ($issueTypeLabels + $priorityLabels + $stateRoutingLabels + $assetLabels | Select-Object -Unique)) {
    if (-not $labelTaxonomy.ToLowerInvariant().Contains($label.ToLowerInvariant())) {
        Add-Finding -Id 'META-100' -Severity 'high' -File 'docs/reference/label-taxonomy.md' -Message "Label '$label' from governance contract is missing in taxonomy reference." -Recommendation "Add '$label' to the appropriate taxonomy section."
    }
}

foreach ($label in ($issueTypeLabels + $priorityLabels)) {
    if (-not $issueTriageWorkflow.ToLowerInvariant().Contains($label.ToLowerInvariant())) {
        Add-Finding -Id 'META-200' -Severity 'high' -File '.github/workflows/issue-triage.md' -Message "Issue-triage workflow prompt is missing canonical label '$label'." -Recommendation "Update issue-triage workflow prompt to include '$label' in taxonomy guidance."
    }
}

foreach ($label in $issueTypeLabels) {
    if (-not $issueTemplate.ToLowerInvariant().Contains($label.ToLowerInvariant())) {
        Add-Finding -Id 'META-300' -Severity 'medium' -File '.github/ISSUE_TEMPLATE/issue.md' -Message "Issue template does not mention canonical issue type '$label'." -Recommendation "Add '$label' to Issue Type options in issue template."
    }
}

foreach ($label in $priorityLabels) {
    if (-not $issueTemplate.ToLowerInvariant().Contains($label.ToLowerInvariant())) {
        Add-Finding -Id 'META-301' -Severity 'medium' -File '.github/ISSUE_TEMPLATE/issue.md' -Message "Issue template does not mention canonical priority '$label'." -Recommendation "Add '$label' to Priority options in issue template."
    }
}

$reportLines = @(
    '# Governance Metadata Drift Report',
    '',
    "Mode: **$Mode**",
    ''
)

if ($findings.Count -eq 0) {
    $reportLines += @(
        'No governance metadata drift detected.',
        '',
        'Checks covered:',
        '- Canonical label extraction from `docs/reference/governance-contract.md`',
        '- Label presence in `docs/reference/label-taxonomy.md`',
        '- Canonical label coverage in `.github/ISSUE_TEMPLATE/issue.md` and `.github/workflows/issue-triage.md`',
        '- Governance contract references in issue and PR templates'
    )
} else {
    $reportLines += @(
        "| ID | Severity | File | Finding | Recommendation | Follow-up |",
        "|---|---|---|---|---|---|"
    )

    foreach ($finding in $findings) {
        $title = "governance metadata drift: $($finding.id)"
        $body = @"
Detected by governance metadata drift workflow.

Finding ID: $($finding.id)
Severity: $($finding.severity)
File: $($finding.file)
Finding: $($finding.message)
Recommendation: $($finding.recommendation)
"@
        $followUp = New-FollowUpIssueLink -Title $title -Body $body
        $followUpCell = if ($followUp) { "[Create issue]($followUp)" } else { 'Open issue manually' }
        $reportLines += "| $($finding.id) | $($finding.severity) | $($finding.file) | $($finding.message) | $($finding.recommendation) | $followUpCell |"
    }
}

$report = ($reportLines -join "`n") + "`n"
Write-Host $report

if ($SummaryPath) {
    Set-Content -Path $SummaryPath -Value $report -Encoding UTF8
}

if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $report
}

if ($findings.Count -gt 0) {
    exit 1
}

exit 0

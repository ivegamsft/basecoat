#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Audits owner-level Projects v2 for portfolio link and milestone drift.

.DESCRIPTION
    For every project owned by -Owner, lists the repositories that contribute
    items, reports contributing repositories that are not linked to the project,
    and reports open issues in sprint/wave projects that have no milestone.

    With -Fix, missing project-to-repository links are created with the GraphQL
    linkProjectV2ToRepository mutation (retry with exponential back-off).
    Milestone gaps are always report-only.

    Exit codes: 0 = no gaps, 1 = gaps remain, 2 = audit could not complete.

.EXAMPLE
    pwsh scripts/audit-portfolio-links.ps1 -Owner <owner> -OutputPath portfolio-links.json

.EXAMPLE
    pwsh scripts/audit-portfolio-links.ps1 -Owner <owner> -Fix
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Owner,
    [switch]$Fix,
    [switch]$IncludeClosed,
    [string]$SprintProjectPattern = '^(Sprint|Wave)\s+\d+',
    [string]$OutputPath,
    [ValidateRange(1, 10)]
    [int]$MaxAttempts = 5,
    [ValidateRange(0, 300)]
    [double]$BaseDelaySeconds = 2,
    [ValidateRange(0, 3600)]
    [double]$SecondaryLimitDelaySeconds = 60,
    [ValidateRange(1, 7200)]
    [double]$MaxWaitSeconds = 900,
    # Test seams: GraphQLInvoker receives (query, variables) and returns the parsed
    # response object; SleepInvoker receives the wait in seconds.
    [scriptblock]$GraphQLInvoker,
    [scriptblock]$SleepInvoker
)

$ErrorActionPreference = 'Stop'

function Invoke-GhGraphQL {
    param([string]$Query, [hashtable]$Variables)

    $body = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 10 -Compress
    $raw = $body | & gh api graphql --input - 2>&1
    $text = ($raw | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "gh api graphql failed: $text"
    }
    return $text | ConvertFrom-Json -Depth 20
}

function Test-RetryableError {
    param([string]$Message)
    return $Message -match '(?i)rate.?limit|secondary|abuse|timeout|timed out|\b50[234]\b|temporarily'
}

function Invoke-RawGraphQL {
    param([string]$Query, [hashtable]$Variables)
    $response = if ($GraphQLInvoker) { & $GraphQLInvoker $Query $Variables } else { Invoke-GhGraphQL -Query $Query -Variables $Variables }
    $errors = @($response.errors | Where-Object { $_ })
    if ($errors.Count -gt 0) {
        $detail = ($errors | ForEach-Object { "$($_.type): $($_.message)" }) -join '; '
        throw "GraphQL error: $detail"
    }
    return $response.data
}

function Get-RateLimitCooldownSeconds {
    param([string]$Message)

    if ($Message -match '(?i)secondary|abuse') {
        return $SecondaryLimitDelaySeconds
    }
    if ($Message -notmatch '(?i)rate.?limit') {
        return 0
    }
    # Primary limit: wait until the server-reported reset; fall back to the secondary delay.
    try {
        $resetAt = [datetimeoffset]::Parse((Invoke-RawGraphQL -Query 'query { rateLimit { resetAt } }' -Variables @{}).rateLimit.resetAt)
        return [math]::Max(0, ($resetAt - [datetimeoffset]::UtcNow).TotalSeconds) + 1
    }
    catch {
        return $SecondaryLimitDelaySeconds
    }
}

function Invoke-PortfolioGraphQL {
    param([string]$Query, [hashtable]$Variables = @{})

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return Invoke-RawGraphQL -Query $Query -Variables $Variables
        }
        catch {
            $message = $_.Exception.Message
            if ($attempt -ge $MaxAttempts -or -not (Test-RetryableError $message)) {
                throw
            }
            $backoff = $BaseDelaySeconds * [math]::Pow(2, $attempt - 1)
            $delay = [math]::Max($backoff, (Get-RateLimitCooldownSeconds -Message $message))
            if ($delay -gt $MaxWaitSeconds) {
                throw "Required wait of ${delay}s exceeds MaxWaitSeconds ($MaxWaitSeconds): $message"
            }
            Write-Warning "Retryable GraphQL failure (attempt $attempt/$MaxAttempts); waiting ${delay}s: $message"
            if ($SleepInvoker) { & $SleepInvoker $delay } else { Start-Sleep -Milliseconds ([int]($delay * 1000)) }
        }
    }
}

$projectsQuery = @'
query($owner: String!, $cursor: String) {
  repositoryOwner(login: $owner) {
    ... on Organization { projectsV2(first: 50, after: $cursor) { nodes { id number title closed repositories(first: 100) { nodes { nameWithOwner } } } pageInfo { hasNextPage endCursor } } }
    ... on User { projectsV2(first: 50, after: $cursor) { nodes { id number title closed repositories(first: 100) { nodes { nameWithOwner } } } pageInfo { hasNextPage endCursor } } }
  }
}
'@

$itemsQuery = @'
query($projectId: ID!, $cursor: String) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100, after: $cursor) {
        nodes { content {
          ... on Issue { __typename number url state repository { nameWithOwner } milestone { title } }
          ... on PullRequest { __typename number url state repository { nameWithOwner } }
        } }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
'@

$repoIdQuery = 'query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { id } }'
$linkMutation = 'mutation($projectId: ID!, $repositoryId: ID!) { linkProjectV2ToRepository(input: { projectId: $projectId, repositoryId: $repositoryId }) { repository { nameWithOwner } } }'

function Get-OwnerProjects {
    $projects = [System.Collections.Generic.List[object]]::new()
    $cursor = $null
    do {
        $data = Invoke-PortfolioGraphQL -Query $projectsQuery -Variables @{ owner = $Owner; cursor = $cursor }
        if (-not $data.repositoryOwner) { throw "Owner '$Owner' was not found or is not accessible." }
        $page = $data.repositoryOwner.projectsV2
        foreach ($node in @($page.nodes)) { if ($node) { $projects.Add($node) } }
        $cursor = $page.pageInfo.endCursor
    } while ($page.pageInfo.hasNextPage)
    return $projects
}

function Get-ProjectItems {
    param([string]$ProjectId)
    $items = [System.Collections.Generic.List[object]]::new()
    $cursor = $null
    do {
        $data = Invoke-PortfolioGraphQL -Query $itemsQuery -Variables @{ projectId = $ProjectId; cursor = $cursor }
        $page = $data.node.items
        foreach ($node in @($page.nodes)) { if ($node.content.repository) { $items.Add($node.content) } }
        $cursor = $page.pageInfo.endCursor
    } while ($page.pageInfo.hasNextPage)
    return $items
}

$report = [ordered]@{
    owner          = $Owner
    generatedAt    = (Get-Date).ToUniversalTime().ToString('o')
    fixMode        = [bool]$Fix
    projectsScanned = 0
    unlinkedRepos  = [System.Collections.Generic.List[object]]::new()
    missingMilestones = [System.Collections.Generic.List[object]]::new()
    crossOwnerRepos = [System.Collections.Generic.List[object]]::new()
    linked         = [System.Collections.Generic.List[object]]::new()
    linkFailures   = [System.Collections.Generic.List[object]]::new()
    gapCount       = 0
}

try {
    $repoIds = @{}
    foreach ($project in (Get-OwnerProjects)) {
        if ($project.closed -and -not $IncludeClosed) { continue }
        $report.projectsScanned++

        $linkedRepos = @($project.repositories.nodes | ForEach-Object { $_.nameWithOwner.ToLowerInvariant() })
        $items = Get-ProjectItems -ProjectId $project.id
        $isSprintProject = $project.title -match $SprintProjectPattern

        $contributing = @($items | ForEach-Object { $_.repository.nameWithOwner } | Sort-Object -Unique)
        foreach ($repo in $contributing) {
            if ($linkedRepos -contains $repo.ToLowerInvariant()) { continue }
            $repoOwner, $repoName = $repo -split '/', 2
            $entry = [ordered]@{ project = $project.number; title = $project.title; repository = $repo }
            if ($repoOwner -ne $Owner) {
                $report.crossOwnerRepos.Add($entry)
                continue
            }
            if (-not $Fix) {
                $report.unlinkedRepos.Add($entry)
                continue
            }
            try {
                if (-not $repoIds.ContainsKey($repo)) {
                    $repoIds[$repo] = (Invoke-PortfolioGraphQL -Query $repoIdQuery -Variables @{ owner = $repoOwner; name = $repoName }).repository.id
                }
                $null = Invoke-PortfolioGraphQL -Query $linkMutation -Variables @{ projectId = $project.id; repositoryId = $repoIds[$repo] }
                $report.linked.Add($entry)
            }
            catch {
                $entry.error = $_.Exception.Message
                $report.linkFailures.Add($entry)
                $report.unlinkedRepos.Add($entry)
            }
        }

        if ($isSprintProject) {
            foreach ($item in $items) {
                if ($item.__typename -eq 'Issue' -and $item.state -eq 'OPEN' -and -not $item.milestone) {
                    $report.missingMilestones.Add([ordered]@{
                        project    = $project.number
                        title      = $project.title
                        repository = $item.repository.nameWithOwner
                        issue      = $item.number
                        url        = $item.url
                    })
                }
            }
        }
    }
}
catch {
    Write-Error "Portfolio link audit failed: $($_.Exception.Message)" -ErrorAction Continue
    exit 2
}

$report.gapCount = $report.unlinkedRepos.Count + $report.crossOwnerRepos.Count + $report.missingMilestones.Count
$json = $report | ConvertTo-Json -Depth 8
if ($OutputPath) {
    try {
        $parent = Split-Path -Parent $OutputPath
        if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Set-Content -Path $OutputPath -Value $json -Encoding utf8
    }
    catch {
        Write-Error "Could not write report to '$OutputPath': $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}

Write-Host "Projects scanned: $($report.projectsScanned)"
Write-Host "Unlinked repositories: $($report.unlinkedRepos.Count)"
Write-Host "Open sprint/wave issues without milestone: $($report.missingMilestones.Count)"
Write-Host "Unlinked cross-owner repositories (report-only, never auto-linked): $($report.crossOwnerRepos.Count)"
if ($Fix) { Write-Host "Links created: $($report.linked.Count); link failures: $($report.linkFailures.Count)" }
foreach ($gap in $report.unlinkedRepos) { Write-Host "  GAP unlinked: project #$($gap.project) '$($gap.title)' -> $($gap.repository)" }
foreach ($gap in $report.crossOwnerRepos) { Write-Host "  GAP unlinked cross-owner (manual): project #$($gap.project) '$($gap.title)' -> $($gap.repository)" }
foreach ($gap in $report.missingMilestones) { Write-Host "  GAP no milestone: $($gap.repository)#$($gap.issue) in project #$($gap.project)" }

if (-not $OutputPath) { Write-Output $json }
exit ([int]($report.gapCount -gt 0))

#!/usr/bin/env pwsh
# project-sync.ps1 - Idempotent backlog-rebalance-engine project sync
# Onboards rebalanced issues into a GitHub Project board and aligns item status.
# Emits a sync report: added=<n> updated=<n> skipped=<n>
#
# Usage:
#   ./project-sync.ps1 -Owner <org> -Project <title> -Repo <owner/repo> `
#     [-Label <sprint:N>] [-IssueListFile <path>] [-DryRun]

[CmdletBinding()]
param(
    [Parameter(Mandatory)]  [string] $Owner,
    [Parameter(Mandatory)]  [string] $Project,
    [Parameter(Mandatory)]  [string] $Repo,
    [string] $Label = "",
    [string] $IssueListFile = "",
    [string] $StatusOpen   = "Todo",
    [string] $StatusClosed = "Done",
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$MaxRetries = 3

function Invoke-GhWithRetry {
    param([scriptblock] $Command)
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            return & $Command
        } catch {
            if ($attempt -ge $MaxRetries) { throw }
            Write-Warning "Retry $attempt/$MaxRetries after error: $_"
            Start-Sleep -Seconds 10
            $attempt++
        }
    }
}

# Resolve project number
Write-Host "Resolving project: '$Project' for owner '$Owner'..."
$projectList = gh project list --owner $Owner --format json --limit 100 2>$null | ConvertFrom-Json
$projectEntry = $projectList.projects | Where-Object { $_.title -eq $Project } | Select-Object -First 1

if (-not $projectEntry) {
    Write-Error "Project not found: $Project"
    exit 1
}
$projectNumber = $projectEntry.number

# Resolve project node ID (org or user scope)
$projectNodeId = $null
$projectNodeId = Invoke-GhWithRetry {
    gh api graphql -f query='
      query($owner: String!, $number: Int!) {
        organization(login: $owner) {
          projectV2(number: $number) { id }
        }
      }
    ' -f owner=$Owner -F number=$projectNumber --jq '.data.organization.projectV2.id' 2>$null
}
if (-not $projectNodeId) {
    $projectNodeId = Invoke-GhWithRetry {
        gh api graphql -f query='
          query($owner: String!, $number: Int!) {
            user(login: $owner) {
              projectV2(number: $number) { id }
            }
          }
        ' -f owner=$Owner -F number=$projectNumber --jq '.data.user.projectV2.id' 2>$null
    }
}
if (-not $projectNodeId) {
    Write-Error "Could not resolve project node ID for project number $projectNumber."
    exit 1
}

# Resolve Status field and option IDs
Write-Host "Resolving Status field..."
$fieldsJson = Invoke-GhWithRetry {
    gh api graphql -f query='
      query($id: ID!) {
        node(id: $id) {
          ... on ProjectV2 {
            fields(first: 20) {
              nodes {
                ... on ProjectV2SingleSelectField {
                  id name
                  options { id name }
                }
              }
            }
          }
        }
      }
    ' -f id=$projectNodeId --jq '.data.node.fields.nodes' 2>$null
} | ConvertFrom-Json

$statusField = $fieldsJson | Where-Object { $_.name -eq "Status" } | Select-Object -First 1
if (-not $statusField) {
    Write-Error "Status field not found in project."
    exit 1
}

$statusFieldId  = $statusField.id
$optionOpenId   = ($statusField.options | Where-Object { $_.name -eq $StatusOpen }   | Select-Object -First 1).id
$optionClosedId = ($statusField.options | Where-Object { $_.name -eq $StatusClosed } | Select-Object -First 1).id

if (-not $optionOpenId)   { Write-Error "Status option not found: $StatusOpen";   exit 1 }
if (-not $optionClosedId) { Write-Error "Status option not found: $StatusClosed"; exit 1 }

# Snapshot current board items
Write-Host "Fetching current project items..."
$boardRaw = gh project item-list $projectNumber --owner $Owner --format json --limit 2000 2>$null | ConvertFrom-Json
$boardLookup   = @{}  # url -> itemId
$boardStatuses = @{}  # url -> optionId

foreach ($item in $boardRaw.items) {
    $url = $item.content.url
    if (-not $url) { continue }
    $boardLookup[$url]   = $item.id
    $statusOption = $item.fieldValues.nodes | Where-Object { $_.field.name -eq "Status" } | Select-Object -First 1
    $boardStatuses[$url] = if ($statusOption) { $statusOption.optionId } else { "" }
}

# Resolve rebalance issue list
$issues = @()
if ($IssueListFile) {
    $issues = Get-Content $IssueListFile -Raw | ConvertFrom-Json
} else {
    $labelArgs = @()
    if ($Label) { $labelArgs = @("--label", $Label) }
    $issues = gh issue list --repo $Repo --state all --limit 500 @labelArgs `
        --json number,url,title,state 2>$null | ConvertFrom-Json
}

# Process issues
$added   = 0
$updated = 0
$skipped = 0
$addedList   = @()
$updatedList = @()

foreach ($issue in $issues) {
    $number = $issue.number
    $url    = $issue.url
    $title  = $issue.title
    $state  = $issue.state

    $expectedOptionId   = $optionOpenId
    $expectedStatusName = $StatusOpen
    if ($state -eq "CLOSED") {
        $expectedOptionId   = $optionClosedId
        $expectedStatusName = $StatusClosed
    }

    if (-not $boardLookup.ContainsKey($url)) {
        # Item not on board - add
        if ($DryRun) {
            Write-Host "[dry-run] add #$number $title"
        } else {
            $contentNodeId = Invoke-GhWithRetry {
                gh api "repos/$Repo/issues/$number" --jq '.node_id' 2>$null
            }
            $newItemId = Invoke-GhWithRetry {
                gh api graphql -f query='
                  mutation($projectId: ID!, $contentId: ID!) {
                    addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
                      item { id }
                    }
                  }
                ' -f projectId=$projectNodeId -f contentId=$contentNodeId `
                  --jq '.data.addProjectV2ItemById.item.id' 2>$null
            }
            if ($newItemId) {
                Invoke-GhWithRetry {
                    gh api graphql -f query='
                      mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
                        updateProjectV2ItemFieldValue(input: {
                          projectId: $projectId, itemId: $itemId,
                          fieldId: $fieldId, value: { singleSelectOptionId: $optionId }
                        }) { projectV2Item { id } }
                      }
                    ' -f projectId=$projectNodeId -f itemId=$newItemId `
                      -f fieldId=$statusFieldId -f optionId=$expectedOptionId > $null 2>&1
                } | Out-Null
            }
        }
        $added++
        $addedList += "#$number  $title"

    } elseif ($boardStatuses[$url] -ne $expectedOptionId) {
        # Item on board with wrong status - update
        $itemId   = $boardLookup[$url]
        $oldOption = $boardStatuses[$url]
        $oldName  = ($statusField.options | Where-Object { $_.id -eq $oldOption } | Select-Object -First 1).name
        if (-not $oldName) { $oldName = "unknown" }

        if ($DryRun) {
            Write-Host "[dry-run] update #$number $title ($oldName -> $expectedStatusName)"
        } else {
            Invoke-GhWithRetry {
                gh api graphql -f query='
                  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
                    updateProjectV2ItemFieldValue(input: {
                      projectId: $projectId, itemId: $itemId,
                      fieldId: $fieldId, value: { singleSelectOptionId: $optionId }
                    }) { projectV2Item { id } }
                  }
                ' -f projectId=$projectNodeId -f itemId=$itemId `
                  -f fieldId=$statusFieldId -f optionId=$expectedOptionId > $null 2>&1
            } | Out-Null
        }
        $updated++
        $updatedList += "#$number  $title  ($oldName -> $expectedStatusName)"

    } else {
        # Already in sync - skip
        $skipped++
    }
}

# Emit sync report
Write-Host ""
Write-Host "Sync complete: added=$added updated=$updated skipped=$skipped"

if ($addedList.Count -gt 0) {
    Write-Host ""
    Write-Host "Added items:"
    $addedList | ForEach-Object { Write-Host "  $_" }
}

if ($updatedList.Count -gt 0) {
    Write-Host ""
    Write-Host "Updated items:"
    $updatedList | ForEach-Object { Write-Host "  $_" }
}

if ($added -eq 0 -and $updated -eq 0) {
    Write-Host "No changes required -- board is already aligned with rebalance plan."
}

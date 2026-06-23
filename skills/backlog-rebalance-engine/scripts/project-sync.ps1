#!/usr/bin/env pwsh
# project-sync.ps1 - Idempotent backlog-rebalance-engine project sync
# Aligns project status and delivery metadata (priority/sprint/wave) with policy validation,
# freeze-window guardrails, rollback artifact output, and reason-coded per-item changelog.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]  [string] $Owner,
    [Parameter(Mandatory)]  [string] $Project,
    [Parameter(Mandatory)]  [string] $Repo,
    [string] $Label = "",
    [string] $IssueListFile = "",
    [string] $StatusOpen   = "Todo",
    [string] $StatusClosed = "Done",
    [string] $TargetPriorityLabel = "",
    [string] $TargetSprintLabel = "",
    [string] $TargetWaveLabel = "",
    [switch] $FreezeWindow,
    [switch] $AllowFreezeOverride,
    [string] $RollbackArtifactPath = "",
    [string] $ChangeLogPath = "",
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

function Test-PolicyLabel {
    param(
        [string] $Family,
        [string] $LabelValue
    )
    if (-not $LabelValue) { return $true }
    switch ($Family) {
        "priority" { return $LabelValue -match '^priority:(critical|high|medium|low)$' }
        "sprint"   { return $LabelValue -match '^sprint:\d+$' }
        "wave"     { return $LabelValue -match '^wave:\d+$' }
        default    { return $false }
    }
}

function Get-LabelNames {
    param($Issue)
    $result = @()
    if ($Issue.PSObject.Properties.Name -contains "labels") {
        foreach ($label in @($Issue.labels)) {
            if ($label -is [string]) { $result += $label; continue }
            if ($label.name) { $result += $label.name }
        }
    }
    return @($result)
}

function Get-IssueTarget {
    param(
        $Issue,
        [string] $Family,
        [string] $DefaultValue
    )
    if ($Issue.PSObject.Properties.Name -contains "targetMetadata") {
        $tm = $Issue.targetMetadata
        if ($tm -and $tm.PSObject.Properties.Name -contains $Family) {
            return "$($tm.$Family)"
        }
    }
    $k1 = "target$($Family.Substring(0,1).ToUpper())$($Family.Substring(1))Label"
    $k2 = "target_${Family}_label"
    if ($Issue.PSObject.Properties.Name -contains $k1) { return "$($Issue.$k1)" }
    if ($Issue.PSObject.Properties.Name -contains $k2) { return "$($Issue.$k2)" }
    return $DefaultValue
}

function Ensure-OutputPath {
    param([string] $PathValue)
    $dir = Split-Path -Path $PathValue -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Write-Host "Resolving project: '$Project' for owner '$Owner'..."
$projectList = gh project list --owner $Owner --format json --limit 100 2>$null | ConvertFrom-Json
$projectEntry = $projectList.projects | Where-Object { $_.title -eq $Project } | Select-Object -First 1
if (-not $projectEntry) { Write-Error "Project not found: $Project"; exit 1 }
$projectNumber = $projectEntry.number

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
if (-not $statusField) { Write-Error "Status field not found in project."; exit 1 }

$statusFieldId  = $statusField.id
$optionOpenId   = ($statusField.options | Where-Object { $_.name -eq $StatusOpen }   | Select-Object -First 1).id
$optionClosedId = ($statusField.options | Where-Object { $_.name -eq $StatusClosed } | Select-Object -First 1).id
if (-not $optionOpenId)   { Write-Error "Status option not found: $StatusOpen"; exit 1 }
if (-not $optionClosedId) { Write-Error "Status option not found: $StatusClosed"; exit 1 }

if (-not (Test-PolicyLabel -Family "priority" -LabelValue $TargetPriorityLabel)) {
    Write-Error "POLICY_INVALID_TARGET_LABEL: invalid priority target '$TargetPriorityLabel'"
    exit 1
}
if (-not (Test-PolicyLabel -Family "sprint" -LabelValue $TargetSprintLabel)) {
    Write-Error "POLICY_INVALID_TARGET_LABEL: invalid sprint target '$TargetSprintLabel'"
    exit 1
}
if (-not (Test-PolicyLabel -Family "wave" -LabelValue $TargetWaveLabel)) {
    Write-Error "POLICY_INVALID_TARGET_LABEL: invalid wave target '$TargetWaveLabel'"
    exit 1
}

Write-Host "Fetching current project items..."
$boardRaw = gh project item-list $projectNumber --owner $Owner --format json --limit 2000 2>$null | ConvertFrom-Json
$boardLookup   = @{}  # url -> itemId
$boardStatuses = @{}  # url -> optionId
foreach ($item in $boardRaw.items) {
    $url = $item.content.url
    if (-not $url) { continue }
    $boardLookup[$url] = $item.id
    $statusOption = $item.fieldValues.nodes | Where-Object { $_.field.name -eq "Status" } | Select-Object -First 1
    $boardStatuses[$url] = if ($statusOption) { $statusOption.optionId } else { "" }
}

$issues = @()
if ($IssueListFile) {
    $issues = Get-Content $IssueListFile -Raw | ConvertFrom-Json
} else {
    $labelArgs = @()
    if ($Label) { $labelArgs = @("--label", $Label) }
    $issues = gh issue list --repo $Repo --state all --limit 500 @labelArgs --json number,url,title,state,labels 2>$null | ConvertFrom-Json
}

$timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
if (-not $RollbackArtifactPath) { $RollbackArtifactPath = ".\artifacts\backlog-rebalance-rollback-$timestamp.json" }
if (-not $ChangeLogPath) { $ChangeLogPath = ".\artifacts\backlog-rebalance-changelog-$timestamp.json" }
Ensure-OutputPath -PathValue $RollbackArtifactPath
Ensure-OutputPath -PathValue $ChangeLogPath

$plan = @()
$freezeBlocked = @()

foreach ($issue in $issues) {
    $number = $issue.number
    $url = $issue.url
    $title = $issue.title
    $state = $issue.state

    $entry = [ordered]@{
        issueNumber = $number
        issueUrl = $url
        title = $title
        reasonCodes = @()
        actions = @()
    }

    $expectedOptionId = if ($state -eq "CLOSED") { $optionClosedId } else { $optionOpenId }
    $expectedStatusName = if ($state -eq "CLOSED") { $StatusClosed } else { $StatusOpen }

    if (-not $boardLookup.ContainsKey($url)) {
        $entry.reasonCodes += "ADD_TO_PROJECT"
        $entry.actions += [ordered]@{
            type = "project_add"
            expectedStatus = $expectedStatusName
            toOptionId = $expectedOptionId
        }
    } elseif ($boardStatuses[$url] -ne $expectedOptionId) {
        $entry.reasonCodes += "STATUS_MISMATCH"
        $entry.actions += [ordered]@{
            type = "status_update"
            itemId = $boardLookup[$url]
            fromOptionId = $boardStatuses[$url]
            toOptionId = $expectedOptionId
        }
    } else {
        $entry.reasonCodes += "STATUS_ALREADY_ALIGNED"
    }

    $labelNames = Get-LabelNames -Issue $issue
    $targets = [ordered]@{
        priority = (Get-IssueTarget -Issue $issue -Family "priority" -DefaultValue $TargetPriorityLabel)
        sprint   = (Get-IssueTarget -Issue $issue -Family "sprint" -DefaultValue $TargetSprintLabel)
        wave     = (Get-IssueTarget -Issue $issue -Family "wave" -DefaultValue $TargetWaveLabel)
    }
    $familyRegex = [ordered]@{
        priority = '^priority:'
        sprint   = '^sprint:'
        wave     = '^wave:'
    }

    foreach ($family in @("priority","sprint","wave")) {
        $target = $targets[$family]
        if (-not $target) {
            $entry.reasonCodes += "METADATA_NO_TARGET_$($family.ToUpper())"
            continue
        }
        if (-not (Test-PolicyLabel -Family $family -LabelValue $target)) {
            Write-Error "POLICY_INVALID_TARGET_LABEL: invalid $family target '$target' for issue #$number"
            exit 1
        }
        $existing = @($labelNames | Where-Object { $_ -match $familyRegex[$family] })
        if ($existing.Count -eq 1 -and $existing[0] -eq $target) {
            $entry.reasonCodes += "METADATA_ALREADY_ALIGNED_$($family.ToUpper())"
            continue
        }
        $entry.reasonCodes += "METADATA_MUTATION_$($family.ToUpper())"
        $entry.actions += [ordered]@{
            type = "metadata_replace"
            family = $family
            remove = @($existing)
            add = $target
        }
        if ($FreezeWindow -and -not $AllowFreezeOverride) {
            $entry.reasonCodes += "POLICY_FREEZE_WINDOW_BLOCK"
            $freezeBlocked += "#$number"
        }
    }

    $plan += [PSCustomObject]$entry
}

$rollbackOps = @()
$added = 0
$updated = 0
$skipped = 0
$addedList = @()
$updatedList = @()

if ($freezeBlocked.Count -gt 0) {
    $roll = [ordered]@{
        generatedAt = (Get-Date).ToString("o")
        repo = $Repo
        project = $Project
        freezeWindow = $true
        blocked = $true
        operations = @()
    }
    ($roll | ConvertTo-Json -Depth 8) | Set-Content -Path $RollbackArtifactPath -Encoding utf8
    ($plan | ConvertTo-Json -Depth 8) | Set-Content -Path $ChangeLogPath -Encoding utf8
    Write-Error "POLICY_FREEZE_WINDOW_BLOCK: metadata mutation blocked for issues $($freezeBlocked -join ', '). Use -AllowFreezeOverride to proceed."
    exit 1
}

foreach ($entry in $plan) {
    $number = $entry.issueNumber
    $title = $entry.title
    $url = $entry.issueUrl
    $changed = $false

    foreach ($action in $entry.actions) {
        if ($action.type -eq "project_add") {
            if ($DryRun) {
                Write-Host "[dry-run] add #$number $title"
            } else {
                $contentNodeId = Invoke-GhWithRetry { gh api "repos/$Repo/issues/$number" --jq '.node_id' 2>$null }
                $newItemId = Invoke-GhWithRetry {
                    gh api graphql -f query='
                      mutation($projectId: ID!, $contentId: ID!) {
                        addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
                          item { id }
                        }
                      }
                    ' -f projectId=$projectNodeId -f contentId=$contentNodeId --jq '.data.addProjectV2ItemById.item.id' 2>$null
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
                        ' -f projectId=$projectNodeId -f itemId=$newItemId -f fieldId=$statusFieldId -f optionId=$action.toOptionId > $null 2>&1
                    } | Out-Null
                    $rollbackOps += [ordered]@{ type = "project_remove"; itemId = $newItemId; issueNumber = $number }
                }
            }
            $added++
            $changed = $true
            $addedList += "#$number  $title"
            continue
        }

        if ($action.type -eq "status_update") {
            if ($DryRun) {
                Write-Host "[dry-run] update status #$number $title"
            } else {
                Invoke-GhWithRetry {
                    gh api graphql -f query='
                      mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
                        updateProjectV2ItemFieldValue(input: {
                          projectId: $projectId, itemId: $itemId,
                          fieldId: $fieldId, value: { singleSelectOptionId: $optionId }
                        }) { projectV2Item { id } }
                      }
                    ' -f projectId=$projectNodeId -f itemId=$action.itemId -f fieldId=$statusFieldId -f optionId=$action.toOptionId > $null 2>&1
                } | Out-Null
                if ($action.fromOptionId) {
                    $rollbackOps += [ordered]@{
                        type = "status_restore"
                        issueNumber = $number
                        itemId = $action.itemId
                        optionId = $action.fromOptionId
                    }
                }
            }
            $updated++
            $changed = $true
            $updatedList += "#$number  $title"
            continue
        }

        if ($action.type -eq "metadata_replace") {
            if ($DryRun) {
                Write-Host "[dry-run] metadata #$number $($action.family): remove=[$($action.remove -join ',')] add=$($action.add)"
            } else {
                foreach ($rm in @($action.remove)) {
                    Invoke-GhWithRetry { gh issue edit $number --repo $Repo --remove-label $rm > $null 2>&1 } | Out-Null
                    $rollbackOps += [ordered]@{ type = "label_add"; issueNumber = $number; label = $rm }
                }
                Invoke-GhWithRetry { gh issue edit $number --repo $Repo --add-label $action.add > $null 2>&1 } | Out-Null
                $rollbackOps += [ordered]@{ type = "label_remove"; issueNumber = $number; label = $action.add }
            }
            $updated++
            $changed = $true
            $updatedList += "#$number  $title  (metadata:$($action.family))"
            continue
        }
    }

    if (-not $changed) { $skipped++ }
}

$rollback = [ordered]@{
    generatedAt = (Get-Date).ToString("o")
    repo = $Repo
    project = $Project
    dryRun = [bool]$DryRun
    freezeWindow = [bool]$FreezeWindow
    operations = $rollbackOps
    summary = [ordered]@{
        added = $added
        updated = $updated
        skipped = $skipped
    }
}

($rollback | ConvertTo-Json -Depth 8) | Set-Content -Path $RollbackArtifactPath -Encoding utf8
($plan | ConvertTo-Json -Depth 8) | Set-Content -Path $ChangeLogPath -Encoding utf8

Write-Host ""
Write-Host "Sync complete: added=$added updated=$updated skipped=$skipped"
Write-Host "Rollback artifact: $RollbackArtifactPath"
Write-Host "Change log: $ChangeLogPath"

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

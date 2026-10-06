#!/usr/bin/env pwsh

<#
.SYNOPSIS
Validate, preflight, apply, or roll back the repository-owned main queue ruleset.

.DESCRIPTION
The default and -DryRun modes validate local declarative state only.
-Preflight reads live GitHub state and verifies readiness without mutation.
-Apply is explicit and refuses to proceed unless readiness PR #3506 is merged,
the required checks are present on main, and the GitHub Actions check context
was observed on the merged readiness head. Writes are limited to the named
repository-owned ruleset. -Rollback requires the snapshot created by -Apply.

.PARAMETER Apply
Apply the validated repository ruleset and write a rollback snapshot.

.PARAMETER Preflight
Read-only check of live readiness and current branch protections.

.PARAMETER Rollback
Restore the previous repository ruleset or remove the rule created by -Apply.

.PARAMETER DryRun
Validate local declarations without making GitHub API calls.

.PARAMETER BackupPath
Snapshot path for -Apply or -Rollback.
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Preflight,
    [switch]$Rollback,
    [switch]$DryRun,
    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'

$Owner = 'IBuySpy-Shared'
$Repository = 'basecoat'
$RepositorySlug = "$Owner/$Repository"
$RulesetName = 'main-merge-queue-enforcement'
$ReadinessPrNumber = 3506
$GitHubActionsAppId = 15368
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$DesiredPath = Join-Path $RepoRoot '.github\governance\rulesets\main-merge-queue.json'
$PolicyPath = Join-Path $RepoRoot '.github\governance\policy-packs.json'

function Invoke-GhJson {
    param([string[]]$Arguments)

    $output = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $detail = @($output | ForEach-Object { $_.ToString() }) -join "`n"
        throw "GitHub API request failed: gh $($Arguments -join ' ')`n$detail"
    }
    if (-not $output) {
        return $null
    }
    return (($output -join "`n") | ConvertFrom-Json -AsHashtable)
}

function Get-ExpectedChecks {
    param([System.Collections.IDictionary]$Policy)

    $profile = $Policy.profiles.'solo-dev'
    if ($null -eq $profile) {
        throw 'The canonical solo-dev policy profile is missing.'
    }

    $contexts = @($profile.main.required_checks | ForEach-Object { [string]$_ })
    $contexts += 'validate-workflow-syntax'
    $knownCloudChecks = @{
        'Agent merge guardrails' = 'Agent merge guardrails'
    }
    foreach ($cloudCheck in @($profile.cloud_agent.required_status_checks)) {
        $name = [string]$cloudCheck
        if (-not $knownCloudChecks.ContainsKey($name)) {
            throw "No observed GitHub check-context mapping exists for cloud-agent requirement '$name'."
        }
        $contexts += $knownCloudChecks[$name]
    }
    return @($contexts | Select-Object -Unique)
}

function Get-RequiredCheckEntries {
    param([System.Collections.IDictionary]$Ruleset)

    $statusRule = @($Ruleset.rules | Where-Object type -eq 'required_status_checks')
    if ($statusRule.Count -ne 1) {
        throw 'The queue ruleset must contain exactly one required_status_checks rule.'
    }
    return @($statusRule[0].parameters.required_status_checks)
}

function Get-RulesetApiPayload {
    param([System.Collections.IDictionary]$Ruleset)

    $payload = [ordered]@{}
    foreach ($key in @('name', 'target', 'enforcement', 'conditions', 'rules', 'bypass_actors')) {
        if ($Ruleset.Contains($key)) {
            $payload[$key] = $Ruleset[$key]
        }
    }
    return $payload
}

function ConvertTo-CanonicalValue {
    param([object]$Value)

    if ($Value -is [System.Collections.IDictionary]) {
        $canonical = [ordered]@{}
        foreach ($key in @($Value.Keys | Sort-Object -CaseSensitive)) {
            $canonical[$key] = ConvertTo-CanonicalValue $Value[$key]
        }
        return $canonical
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Value) {
            $items.Add((ConvertTo-CanonicalValue $item))
        }
        return ,$items.ToArray()
    }
    return $Value
}

function Get-RulesetFingerprint {
    param([System.Collections.IDictionary]$Ruleset)

    $payload = Get-RulesetApiPayload $Ruleset
    $canonical = ConvertTo-CanonicalValue $payload
    $json = ConvertTo-Json -InputObject $canonical -Depth 100 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Assert-LocalContract {
    if (-not (Test-Path -LiteralPath $DesiredPath)) {
        throw "Missing declarative queue ruleset: $DesiredPath"
    }
    if (-not (Test-Path -LiteralPath $PolicyPath)) {
        throw "Missing governance policy pack: $PolicyPath"
    }

    $desired = Get-Content -LiteralPath $DesiredPath -Raw | ConvertFrom-Json -AsHashtable
    $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json -AsHashtable
    $expectedChecks = Get-ExpectedChecks $policy

    if ($desired.name -ne $RulesetName -or $desired.target -ne 'branch' -or $desired.enforcement -ne 'active') {
        throw 'The declarative ruleset must use the controlled name, active branch target, and enforcement.'
    }
    if (@($desired.conditions.ref_name.include).Count -ne 1 -or
        $desired.conditions.ref_name.include[0] -ne 'refs/heads/main' -or
        @($desired.conditions.ref_name.exclude).Count -ne 0) {
        throw 'The declarative ruleset must target only refs/heads/main.'
    }
    if (@($desired.bypass_actors).Count -ne 0) {
        throw 'The declarative ruleset must not define bypass actors.'
    }
    if (@($desired.rules | Where-Object type -eq 'pull_request').Count -ne 0) {
        throw 'The queue ruleset must not add or change pull-request approval requirements.'
    }

    $entries = Get-RequiredCheckEntries $desired
    $contexts = @($entries | ForEach-Object { [string]$_.context })
    $missing = @($expectedChecks | Where-Object { $_ -notin $contexts })
    $unexpected = @($contexts | Where-Object { $_ -notin $expectedChecks })
    if ($missing.Count -gt 0 -or $unexpected.Count -gt 0 -or $contexts.Count -ne $expectedChecks.Count) {
        throw "Required status contexts must match the solo-dev main checks, queue-only syntax gate, and cloud-agent contracts exactly. Missing: $($missing -join ', '); unexpected: $($unexpected -join ', ')."
    }
    foreach ($entry in $entries) {
        if ([int]$entry.integration_id -ne $GitHubActionsAppId) {
            throw "Required check '$($entry.context)' must be bound to the observed GitHub Actions app ($GitHubActionsAppId)."
        }
    }
    $statusRule = @($desired.rules | Where-Object type -eq 'required_status_checks')[0]
    $queueRule = @($desired.rules | Where-Object type -eq 'merge_queue')[0]
    if ($desired.rules.Count -ne 2 -or $null -eq $queueRule -or
        -not $statusRule.parameters.strict_required_status_checks_policy) {
        throw 'The ruleset must contain only strict required checks and merge_queue rules.'
    }
    if ($queueRule.parameters.grouping_strategy -ne 'ALLGREEN' -or
        $queueRule.parameters.merge_method -ne 'SQUASH' -or
        $queueRule.parameters.max_entries_to_build -ne 1 -or
        $queueRule.parameters.max_entries_to_merge -ne 1) {
        throw 'The queue must use ALLGREEN, squash, and single-entry build/merge limits.'
    }

    $workflowContracts = @{
        '.github\workflows\ci.yml' = @('lint-and-validate:', 'test:')
        '.github\workflows\validate-basecoat.yml' = @('validate-workflow-syntax:', 'validate-commit-messages:', 'validate-unix:', 'validate-windows:')
        '.github\workflows\pr-validation.yml' = @('release-label-gate:', 'scripts/merge-group-release-labels.cjs')
        '.github\workflows\agent-merge.yml' = @('name: Agent merge guardrails')
    }
    foreach ($path in $workflowContracts.Keys) {
        $content = Get-Content -LiteralPath (Join-Path $RepoRoot $path) -Raw
        if ($content -notmatch '(?m)^\s{2}merge_group:\s*$') {
            throw "$path must declare merge_group before the queue can be configured."
        }
        foreach ($contract in $workflowContracts[$path]) {
            if ($content -notmatch [regex]::Escape($contract)) {
                throw "$path is missing required queue-readiness contract '$contract'."
            }
        }
    }

    return @{
        Desired = $desired
        Policy = $policy
        ExpectedChecks = $expectedChecks
    }
}

function Get-MainFileContent {
    param([string]$Path)

    try {
        $response = Invoke-GhJson @('api', "/repos/$RepositorySlug/contents/$Path`?ref=main")
    } catch {
        if ($Path -eq '.github/governance/rulesets/main-merge-queue.json' -and
            $_.Exception.Message -match '404|Not Found') {
            throw 'Queue activation blocked: the reviewed declarative ruleset is not yet present on live main. Merge the configuration PR before applying.'
        }
        throw
    }
    if (-not $response.content) {
        throw "Live main has no readable workflow content at '$Path'."
    }
    $encoded = [string]$response.content
    $bytes = [Convert]::FromBase64String(($encoded -replace '\s', ''))
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Assert-LiveReadiness {
    $readiness = Invoke-GhJson @(
        'pr', 'view', [string]$ReadinessPrNumber, '--repo', $RepositorySlug,
        '--json', 'state,mergedAt,mergeCommit,headRefOid'
    )
    if ($readiness.state -ne 'MERGED' -or -not $readiness.mergedAt -or -not $readiness.headRefOid) {
        throw "Queue activation blocked: readiness PR #$ReadinessPrNumber must be merged before apply."
    }

    $workflowContracts = @{
        '.github/workflows/ci.yml' = @('lint-and-validate:', 'test:')
        '.github/workflows/validate-basecoat.yml' = @('merge_group:', 'validate-commit-messages:', 'validate-unix:', 'validate-windows:')
        '.github/workflows/pr-validation.yml' = @('merge_group:', 'release-label-gate:', 'scripts/merge-group-release-labels.cjs')
        '.github/workflows/agent-merge.yml' = @('merge_group:', 'name: Agent merge guardrails')
    }
    foreach ($path in $workflowContracts.Keys) {
        $content = Get-MainFileContent $path
        if ($content -notmatch '(?m)^\s{2}merge_group:\s*$') {
            throw "Queue activation blocked: live main is missing merge_group in $path."
        }
        foreach ($contract in $workflowContracts[$path]) {
            if ($content -notmatch [regex]::Escape($contract)) {
                throw "Queue activation blocked: live main $path is missing '$contract'."
            }
        }
    }

    $checkRunEndpoint = "/repos/$RepositorySlug/commits/$($readiness.headRefOid)/check-runs?per_page=100"
    $guardRuns = & gh api --paginate --jq '.check_runs[] | select(.name == "Agent merge guardrails") | {name, app_id: .app.id, conclusion, head_sha} | @json' $checkRunEndpoint
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read the cloud-agent check runs on the merged readiness head.'
    }
    $verifiedGuard = $false
    foreach ($line in @($guardRuns)) {
        if ([string]::IsNullOrWhiteSpace([string]$line)) { continue }
        $run = [string]$line | ConvertFrom-Json
        if ($run.name -eq 'Agent merge guardrails' -and
            [int]$run.app_id -eq $GitHubActionsAppId -and
            $run.conclusion -eq 'success' -and
            $run.head_sha -eq $readiness.headRefOid) {
            $verifiedGuard = $true
            break
        }
    }
    if (-not $verifiedGuard) {
        throw "Queue activation blocked: no successful '$($script:CloudGuardContext)' check from GitHub Actions was observed on readiness head $($readiness.headRefOid)."
    }

    $protection = Invoke-GhJson @('api', "/repos/$RepositorySlug/branches/main/protection")
    if (-not $protection.required_status_checks.strict) {
        throw 'Queue activation blocked: main must retain strict required status checks.'
    }
    $currentContexts = @($protection.required_status_checks.contexts | ForEach-Object { [string]$_ })
    $desiredContexts = @(Get-RequiredCheckEntries $script:Desired | ForEach-Object { [string]$_.context })
    $missingExisting = @($currentContexts | Where-Object { $_ -notin $desiredContexts })
    if ($missingExisting.Count -gt 0) {
        throw "Queue activation blocked: the declarative ruleset would omit current main protection checks: $($missingExisting -join ', ')."
    }

    $repository = Invoke-GhJson @('api', "/repos/$RepositorySlug")
    if (-not $repository.allow_squash_merge) {
        throw 'Queue activation blocked: the repository does not currently allow squash merging.'
    }

    $rulesets = @(Invoke-GhJson @('api', "/repos/$RepositorySlug/rulesets?per_page=100"))
    $sameName = @($rulesets | Where-Object name -eq $RulesetName)
    if (@($sameName | Where-Object source -ne $RepositorySlug).Count -gt 0) {
        throw 'Queue activation blocked: an organization- or enterprise-owned ruleset uses the target name; it will not be modified.'
    }
    if ($sameName.Count -gt 1) {
        throw 'Queue activation blocked: multiple rulesets use the target name; resolve the duplicate before applying.'
    }

    $mainRulesetContent = Get-MainFileContent '.github/governance/rulesets/main-merge-queue.json'
    $mainRuleset = $mainRulesetContent | ConvertFrom-Json -AsHashtable
    if ((Get-RulesetFingerprint $mainRuleset) -ne (Get-RulesetFingerprint $script:Desired)) {
        throw 'Queue activation blocked: live main does not contain the exact reviewed declarative queue ruleset.'
    }

    return @{
        Readiness = $readiness
        Protection = $protection
        Repository = $repository
        ExistingRuleset = if ($sameName.Count -eq 1) { $sameName[0] } else { $null }
    }
}

function Save-Snapshot {
    param(
        [string]$Path,
        [System.Collections.IDictionary]$Snapshot
    )

    $json = ConvertTo-Json -InputObject $Snapshot -Depth 100
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
}

function Get-RulesetById {
    param([int]$Id)

    return Invoke-GhJson @('api', "/repos/$RepositorySlug/rulesets/$Id")
}

function Restore-Snapshot {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        throw 'Rollback requires the existing snapshot path printed by the successful -Apply operation.'
    }
    $snapshot = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    if ($snapshot.repository -ne $RepositorySlug -or $snapshot.ruleset_name -ne $RulesetName) {
        throw 'Rollback refused: snapshot repository or ruleset identity does not match this deployment.'
    }
    if (-not $snapshot.applied_id) {
        throw 'Rollback refused: snapshot does not contain a verified applied ruleset ID.'
    }

    $current = Get-RulesetById ([int]$snapshot.applied_id)
    if ($current.name -ne $RulesetName -or $current.source -ne $RepositorySlug) {
        throw 'Rollback refused: current ruleset is not the repository-owned target recorded by this snapshot.'
    }
    if ((Get-RulesetFingerprint $current) -ne $snapshot.applied_fingerprint) {
        throw 'Rollback refused: target ruleset changed after apply; review and restore it manually.'
    }

    if ($snapshot.created) {
        & gh api --method DELETE "/repos/$RepositorySlug/rulesets/$($snapshot.applied_id)" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to remove the repository-owned ruleset created by this apply.'
        }
        Write-Host "Removed repository-owned ruleset $($snapshot.applied_id)."
        return
    }

    $restorePath = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + '.json')
    try {
        $previousPayload = Get-RulesetApiPayload $snapshot.previous
        Set-Content -LiteralPath $restorePath -Value (ConvertTo-Json -InputObject $previousPayload -Depth 100) -Encoding utf8
        $null = Invoke-GhJson @(
            'api', '--method', 'PUT', '--input', $restorePath,
            "/repos/$RepositorySlug/rulesets/$($snapshot.applied_id)"
        )
    } finally {
        Remove-Item -LiteralPath $restorePath -ErrorAction SilentlyContinue
    }
    $restored = Get-RulesetById ([int]$snapshot.applied_id)
    if ((Get-RulesetFingerprint $restored) -ne $snapshot.previous_fingerprint) {
        throw 'Rollback request completed but the previous repository ruleset did not verify.'
    }
    Write-Host "Restored prior repository-owned ruleset $($snapshot.applied_id)."
}

function Apply-Ruleset {
    param(
        [System.Collections.IDictionary]$Desired,
        [System.Collections.IDictionary]$ExistingRuleset,
        [string]$SnapshotPath
    )

    if (-not $SnapshotPath) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $SnapshotPath = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-main-merge-queue-$stamp-$([guid]::NewGuid().ToString('N')).json"
    }
    if (Test-Path -LiteralPath $SnapshotPath) {
        throw "Refusing to overwrite existing rollback snapshot: $SnapshotPath"
    }

    $previous = $null
    if ($null -ne $ExistingRuleset) {
        $previous = Get-RulesetById ([int]$ExistingRuleset.id)
    }
    $snapshot = [ordered]@{
        repository = $RepositorySlug
        ruleset_name = $RulesetName
        created = ($null -eq $previous)
        applied_id = if ($null -ne $previous) { [int]$previous.id } else { 0 }
        applied_fingerprint = Get-RulesetFingerprint $Desired
        previous = $previous
        previous_fingerprint = if ($null -ne $previous) { Get-RulesetFingerprint $previous } else { $null }
    }
    Save-Snapshot -Path $SnapshotPath -Snapshot $snapshot

    $applyPath = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + '.json')
    try {
        $payload = Get-RulesetApiPayload $Desired
        Set-Content -LiteralPath $applyPath -Value (ConvertTo-Json -InputObject $payload -Depth 100) -Encoding utf8
        if ($null -eq $previous) {
            $result = Invoke-GhJson @(
                'api', '--method', 'POST', '--input', $applyPath,
                "/repos/$RepositorySlug/rulesets"
            )
        } else {
            $result = Invoke-GhJson @(
                'api', '--method', 'PUT', '--input', $applyPath,
                "/repos/$RepositorySlug/rulesets/$($previous.id)"
            )
        }
    } finally {
        Remove-Item -LiteralPath $applyPath -ErrorAction SilentlyContinue
    }

    $snapshot.applied_id = [int]$result.id
    Save-Snapshot -Path $SnapshotPath -Snapshot $snapshot
    $verified = Get-RulesetById ([int]$result.id)
    if ($verified.source -ne $RepositorySlug -or
        (Get-RulesetFingerprint $verified) -ne $snapshot.applied_fingerprint) {
        throw "Ruleset apply did not verify exactly. Do not retry blindly; inspect GitHub state and use snapshot '$SnapshotPath' if rollback is needed."
    }

    Write-Host "Applied and verified repository-owned ruleset $($result.id) for refs/heads/main."
    Write-Host "Rollback snapshot: $SnapshotPath"
}

$modeCount = @(@($Apply, $Preflight, $Rollback, $DryRun) | Where-Object { $_ }).Count
if ($modeCount -gt 1) {
    throw 'Choose only one mode: default/-DryRun, -Preflight, -Apply, or -Rollback.'
}

$local = Assert-LocalContract
$script:Desired = $local.Desired
$script:CloudGuardContext = 'Agent merge guardrails'
if ($Rollback) {
    Restore-Snapshot -Path $BackupPath
    exit 0
}
if ($Apply -or $Preflight) {
    if ($Apply) {
        $actor = Invoke-GhJson @('api', 'user')
        if ($actor.login -ne 'ibuyspy') {
            throw "Apply must run as the authorized ibuyspy account; active gh user is '$($actor.login)'."
        }
    }
    $live = Assert-LiveReadiness
    if ($Preflight) {
        Write-Host "Read-only preflight passed. Readiness PR #$ReadinessPrNumber is merged; live main protection and check identities are intact."
        if ($null -eq $live.ExistingRuleset) {
            Write-Host 'The target repository-owned ruleset does not exist; -Apply would create it.'
        } else {
            Write-Host "The existing repository-owned target is ruleset $($live.ExistingRuleset.id); -Apply would update only that ruleset."
        }
        Write-Host 'No ruleset or branch protection was changed.'
        exit 0
    }
    Apply-Ruleset -Desired $local.Desired -ExistingRuleset $live.ExistingRuleset -SnapshotPath $BackupPath
    exit 0
}

Write-Host "Validated local queue declaration: $DesiredPath"
Write-Host 'No GitHub API calls or changes were made. Run -Preflight for live read-only checks.'

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running project rules drift audit tests...'

$helpersPath = Join-Path $repoRoot 'scripts\project-rules-drift-audit-helpers.ps1'
$baselinePath = Join-Path $repoRoot 'scripts\project-rules-baseline.json'

if (-not (Test-Path $helpersPath)) {
    throw "Missing helper script: $helpersPath"
}

if (-not (Test-Path $baselinePath)) {
    throw "Missing baseline manifest: $baselinePath"
}

. $helpersPath

# Parse-level regression for the main audit script: the -ProjId argument fix replaced an
# invalid inline `if (...) {...}` expression passed directly as a parameter. Parsing the
# script here fails if that (or any other) syntax regression is reintroduced.
$mainScriptPath = Join-Path $repoRoot 'scripts\project-rules-drift-audit.ps1'
if (-not (Test-Path $mainScriptPath)) {
    throw "Missing main audit script: $mainScriptPath"
}
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($mainScriptPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors -and $parseErrors.Count -gt 0) {
    throw "Main audit script has parse errors: $(( $parseErrors | ForEach-Object { $_.Message } ) -join '; ')"
}

$baseline = Get-Content -Path $baselinePath -Raw | ConvertFrom-Json -Depth 100
$rule1 = $baseline.rules | Where-Object { $_.rule_id -eq 'PRD-001' } | Select-Object -First 1
$rule2 = $baseline.rules | Where-Object { $_.rule_id -eq 'PRD-002' } | Select-Object -First 1
$sampleRules = @($rule1, $rule2)

# PRD-001 is present, enabled, and its trigger/action signature matches baseline -> no finding.
# PRD-002 is present but disabled in the live project -> enabled-state drift (its
# trigger/action signature otherwise matches baseline, isolating the enabled-only case).
# 'Untracked workflow' has no baseline entry -> extra drift.
$liveProject = [pscustomobject]@{
    workflows = [pscustomobject]@{
        nodes = @(
            [pscustomobject]@{
                name = $rule1.name
                enabled = $true
                triggers = @([pscustomobject]@{ pullRequestEvent = $rule1.condition.event })
                actions = @([pscustomobject]@{ field = [pscustomobject]@{ name = $rule1.action.field }; value = $rule1.action.value })
            },
            [pscustomobject]@{
                name = $rule2.name
                enabled = $false
                triggers = @([pscustomobject]@{ pullRequestEvent = $rule2.condition.event })
                actions = @([pscustomobject]@{ field = [pscustomobject]@{ name = $rule2.action.field }; value = $rule2.action.value })
            },
            [pscustomobject]@{
                name = 'Untracked workflow'
                enabled = $true
                triggers = @()
                actions = @()
            }
        )
    }
}

$findings = @(Compare-Rules -BaselineRules $sampleRules -LiveProject $liveProject)

if ($findings.Count -ne 2) {
    throw "Expected 2 findings (enabled drift + extra), got $($findings.Count)"
}

$enabledDrift = $findings | Where-Object { $_.finding_id -eq 'PRD-002-modified-enabled' }
if ($null -eq $enabledDrift) {
    throw 'Missing enabled-state drift finding for PRD-002.'
}
if ($enabledDrift.drift_type -ne 'modified') {
    throw "Expected PRD-002 enabled drift to be drift_type 'modified', got '$($enabledDrift.drift_type)'."
}

# With matching trigger/action signatures, no condition/action drift findings should appear.
$signatureDrift = $findings | Where-Object { $_.finding_id -like '*-modified-condition' -or $_.finding_id -like '*-modified-action' }
if ($null -ne $signatureDrift) {
    throw 'Did not expect condition/action drift findings when live triggers/actions match baseline.'
}

$extraDrift = $findings | Where-Object { $_.drift_type -eq 'extra' }
if ($null -eq $extraDrift -or $extraDrift.rule_name -ne 'Untracked workflow') {
    throw 'Missing extra workflow drift finding.'
}

# Condition/action shape drift: a rule redirected to a different trigger event and a
# different action field/value must be caught even though name/enabled still match,
# guarding against a rule being silently repointed at the wrong event.
$redirectedLiveProject = [pscustomobject]@{
    workflows = [pscustomobject]@{
        nodes = @(
            [pscustomobject]@{
                name = $rule1.name
                enabled = $true
                triggers = @([pscustomobject]@{ pullRequestEvent = 'closed' })
                actions = @([pscustomobject]@{ field = [pscustomobject]@{ name = 'Status' }; value = 'Blocked' })
            }
        )
    }
}
$redirectedFindings = @(Compare-Rules -BaselineRules @($rule1) -LiveProject $redirectedLiveProject)
$conditionDrift = $redirectedFindings | Where-Object { $_.finding_id -eq 'PRD-001-modified-condition' }
if ($null -eq $conditionDrift) {
    throw 'Expected a condition drift finding when the live trigger event no longer matches the baseline.'
}
$actionDrift = $redirectedFindings | Where-Object { $_.finding_id -eq 'PRD-001-modified-action' }
if ($null -eq $actionDrift) {
    throw 'Expected an action drift finding when the live action value no longer matches the baseline.'
}

# A baseline rule with no matching live workflow -> missing drift.
$missingOnly = @(Compare-Rules -BaselineRules @($rule1) -LiveProject ([pscustomobject]@{
    workflows = [pscustomobject]@{ nodes = @() }
}))
if ($missingOnly.Count -ne 1 -or $missingOnly[0].finding_id -ne 'PRD-001-missing') {
    throw 'Expected a single PRD-001-missing finding when the live workflow is absent.'
}

# Regression: label_added conditions declare a label *prefix* (e.g. "sprint:"),
# not an exact label name. A legitimate live trigger on an actual applied
# label like "sprint:42" must NOT be reported as condition drift just because
# its full signature ("label_added:sprint:42") differs from the baseline
# prefix signature ("label_added:sprint:").
$labelPrefixRule = [pscustomobject]@{
    rule_id = 'PRD-STRICT-LABEL-PREFIX'
    name = 'Label prefix rule probe'
    enabled = $true
    severity_if_missing = 'low'
    condition = [pscustomobject]@{ type = 'label_added'; label_prefix = 'sprint:' }
    action = [pscustomobject]@{ type = 'add_to_project' }
}
$labelPrefixLiveProject = [pscustomobject]@{
    workflows = [pscustomobject]@{
        nodes = @(
            [pscustomobject]@{
                name = $labelPrefixRule.name
                enabled = $true
                triggers = @([pscustomobject]@{ label = [pscustomobject]@{ name = 'sprint:42' } })
                actions = @([pscustomobject]@{ dummy = $true })
            }
        )
    }
}
$labelPrefixFindings = @(Compare-Rules -BaselineRules @($labelPrefixRule) -LiveProject $labelPrefixLiveProject)
if ($labelPrefixFindings.Count -ne 0) {
    throw "Expected no drift findings for a live label matching the baseline prefix, got $($labelPrefixFindings.Count): $(($labelPrefixFindings | ForEach-Object { $_.finding_id }) -join ', ')"
}

# A label that does NOT start with the baseline prefix must still be flagged.
$labelPrefixMismatchLiveProject = [pscustomobject]@{
    workflows = [pscustomobject]@{
        nodes = @(
            [pscustomobject]@{
                name = $labelPrefixRule.name
                enabled = $true
                triggers = @([pscustomobject]@{ label = [pscustomobject]@{ name = 'area:frontend' } })
                actions = @([pscustomobject]@{ dummy = $true })
            }
        )
    }
}
$labelPrefixMismatchFindings = @(Compare-Rules -BaselineRules @($labelPrefixRule) -LiveProject $labelPrefixMismatchLiveProject)
$labelConditionDrift = $labelPrefixMismatchFindings | Where-Object { $_.finding_id -eq 'PRD-STRICT-LABEL-PREFIX-modified-condition' }
if ($null -eq $labelConditionDrift) {
    throw 'Expected a condition drift finding when the live label does not start with the baseline prefix.'
}

# Regression: skills/project-rules-drift-audit/SKILL.md:57 fixes condition/action
# deviations at `high` severity unconditionally -- it must NOT be scaled down to
# the rule's own severity_if_missing (which governs the *absent* case, not the
# *deviated* case). $labelPrefixRule declares severity_if_missing = 'low', so a
# finding of 'low' here would indicate the bug has regressed.
if ($labelConditionDrift.severity -ne 'high') {
    throw "Expected condition drift severity to be 'high' regardless of severity_if_missing ('$($labelPrefixRule.severity_if_missing)'), got '$($labelConditionDrift.severity)'."
}

# Regression: GraphQL union-typed trigger/action objects for non-pull-request
# variants (issue, label-added, item-added, archive) omit every field
# belonging to other variants entirely (not just $null), and the main audit
# script runs under Set-StrictMode -Version Latest. A direct property access
# on an absent field throws PropertyNotFoundException instead of returning
# $null, so Get-LiveTriggerSignature/Get-LiveActionSignature must guard every
# optional field through PSObject.Properties. Exercise all four non-PR
# variants here, under StrictMode, so a regression to direct property access
# fails this test instead of only surfacing in a live workflow run.
Set-StrictMode -Version Latest
$issueRule = [pscustomobject]@{
    rule_id = 'PRD-STRICT-ISSUE'
    name = 'Issue rule probe'
    enabled = $true
    severity_if_missing = 'low'
    condition = [pscustomobject]@{ type = 'issue_event'; event = 'opened' }
    action = [pscustomobject]@{ type = 'set_field'; field = 'Status'; value = 'Triage' }
}
$labelRule = [pscustomobject]@{
    rule_id = 'PRD-STRICT-LABEL'
    name = 'Label rule probe'
    enabled = $true
    severity_if_missing = 'low'
    condition = [pscustomobject]@{ type = 'label_added'; label_prefix = 'area:' }
    action = [pscustomobject]@{ type = 'add_to_project' }
}
$addRule = [pscustomobject]@{
    rule_id = 'PRD-STRICT-ADD'
    name = 'Item added rule probe'
    enabled = $true
    severity_if_missing = 'low'
    condition = [pscustomobject]@{ type = 'item_added_to_project' }
    action = [pscustomobject]@{ type = 'set_field'; field = 'Status'; value = 'New' }
}
$archiveRule = [pscustomobject]@{
    rule_id = 'PRD-STRICT-ARCHIVE'
    name = 'Archive rule probe'
    enabled = $true
    severity_if_missing = 'low'
    condition = [pscustomobject]@{ type = 'field_value_change'; field = 'Status'; value = 'Done' }
    action = [pscustomobject]@{ type = 'archive_item' }
}
$strictLiveProject = [pscustomobject]@{
    workflows = [pscustomobject]@{
        nodes = @(
            [pscustomobject]@{
                name = $issueRule.name
                enabled = $true
                triggers = @([pscustomobject]@{ issueEvent = 'opened' })
                actions = @([pscustomobject]@{ field = [pscustomobject]@{ name = 'Status' }; value = 'Triage' })
            },
            [pscustomobject]@{
                name = $labelRule.name
                enabled = $true
                triggers = @([pscustomobject]@{ label = [pscustomobject]@{ name = 'area:' } })
                actions = @([pscustomobject]@{ dummy = $true })
            },
            [pscustomobject]@{
                name = $addRule.name
                enabled = $true
                triggers = @([pscustomobject]@{ addWhen = $true })
                actions = @([pscustomobject]@{ field = [pscustomobject]@{ name = 'Status' }; value = 'New' })
            },
            [pscustomobject]@{
                name = $archiveRule.name
                enabled = $true
                triggers = @([pscustomobject]@{ field = [pscustomobject]@{ name = 'Status' }; value = 'Done' })
                actions = @([pscustomobject]@{ archived = $true })
            }
        )
    }
}
$strictFindings = @(Compare-Rules -BaselineRules @($issueRule, $labelRule, $addRule, $archiveRule) -LiveProject $strictLiveProject)
if ($strictFindings.Count -ne 0) {
    throw "Expected no drift findings for matching issue/label/add/archive variants under StrictMode, got $($strictFindings.Count): $(($strictFindings | ForEach-Object { $_.finding_id }) -join ', ')"
}
Set-StrictMode -Off


# matches must still report 0 (the @() guard) rather than throwing on $null.Count.
Set-StrictMode -Version Latest
$singleSummary = Get-DriftTypeSummary -Findings $missingOnly
if ($singleSummary.missing -ne 1 -or $singleSummary.modified -ne 0 -or $singleSummary.extra -ne 0) {
    throw "Expected by_drift_type missing=1/modified=0/extra=0 for a single missing finding, got missing=$($singleSummary.missing) modified=$($singleSummary.modified) extra=$($singleSummary.extra)."
}
$twoSummary = Get-DriftTypeSummary -Findings $findings
if ($twoSummary.missing -ne 0 -or $twoSummary.modified -ne 1 -or $twoSummary.extra -ne 1) {
    throw "Expected by_drift_type missing=0/modified=1/extra=1 for the mixed fixture, got missing=$($twoSummary.missing) modified=$($twoSummary.modified) extra=$($twoSummary.extra)."
}
Set-StrictMode -Off

# Get-DriftOutcome maps per-severity counts to the contract section 2a outcome.
if ((Get-DriftOutcome -Summary @{ critical = 1; high = 0; medium = 0; low = 0 }) -ne 'fail') { throw 'Get-DriftOutcome: any critical must be fail.' }
if ((Get-DriftOutcome -Summary @{ critical = 0; high = 1; medium = 0; low = 0 }) -ne 'fail') { throw 'Get-DriftOutcome: any high must be fail.' }
if ((Get-DriftOutcome -Summary @{ critical = 0; high = 0; medium = 2; low = 0 }) -ne 'warn') { throw 'Get-DriftOutcome: medium-only must be warn.' }
if ((Get-DriftOutcome -Summary @{ critical = 0; high = 0; medium = 0; low = 3 }) -ne 'warn') { throw 'Get-DriftOutcome: low-only must be warn.' }
if ((Get-DriftOutcome -Summary @{ critical = 0; high = 0; medium = 0; low = 0 }) -ne 'pass') { throw 'Get-DriftOutcome: no findings must be pass.' }

Write-Host 'Project rules drift audit tests passed' -ForegroundColor Green
exit 0

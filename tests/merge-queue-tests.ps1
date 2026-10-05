#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

$rulesetPath = '.github/governance/rulesets/main-merge-queue.json'
$scriptPath = 'scripts/deploy-merge-queue.ps1'
$docPath = 'docs/operations/merge-queue-enforcement.md'
$ruleset = Get-Content -LiteralPath $rulesetPath -Raw | ConvertFrom-Json
$policy = Get-Content -LiteralPath '.github/governance/policy-packs.json' -Raw | ConvertFrom-Json
$script = Get-Content -LiteralPath $scriptPath -Raw
$doc = Get-Content -LiteralPath $docPath -Raw

Assert-True ($ruleset.name -eq 'main-merge-queue-enforcement') 'Ruleset name must match the controlled deployment target.'
Assert-True ($ruleset.target -eq 'branch' -and $ruleset.enforcement -eq 'active') 'Ruleset must be an active branch ruleset.'
Assert-True (@($ruleset.conditions.ref_name.include).Count -eq 1 -and $ruleset.conditions.ref_name.include[0] -eq 'refs/heads/main') 'Ruleset must target main only.'
Assert-True (@($ruleset.bypass_actors).Count -eq 0) 'Ruleset must not allow bypass actors.'
Assert-True (@($ruleset.rules | Where-Object type -eq 'pull_request').Count -eq 0) 'Queue ruleset must not alter review or approval requirements.'
Assert-True ($policy.profiles.'solo-dev'.main.merge_queue_posture -eq 'deferred') 'Queue activation must not change trusted policy-pack posture.'

$expectedContexts = @($policy.profiles.'solo-dev'.main.required_checks) +
    @($policy.profiles.'solo-dev'.cloud_agent.required_status_checks)
$statusRule = @($ruleset.rules | Where-Object type -eq 'required_status_checks')
$queueRule = @($ruleset.rules | Where-Object type -eq 'merge_queue')
Assert-True ($statusRule.Count -eq 1 -and $queueRule.Count -eq 1) 'Ruleset must contain exactly one required-check rule and one queue rule.'
Assert-True ($statusRule[0].parameters.strict_required_status_checks_policy) 'Ruleset must retain strict required-check enforcement.'
$configuredContexts = @($statusRule[0].parameters.required_status_checks | ForEach-Object { [string]$_.context })
Assert-True ($configuredContexts.Count -eq $expectedContexts.Count) 'Ruleset must require exactly the policy and cloud-agent status contexts.'
foreach ($context in $expectedContexts) {
    Assert-True ($context -in $configuredContexts) "Ruleset is missing canonical required context '$context'."
}
Assert-True ('Agent merge guardrails' -in $configuredContexts) 'Cloud-agent context must use the observed check-run job name.'
foreach ($check in $statusRule[0].parameters.required_status_checks) {
    Assert-True ([int]$check.integration_id -eq 15368) "Check '$($check.context)' must be bound to the observed GitHub Actions app."
}

Assert-True ($queueRule[0].parameters.grouping_strategy -eq 'ALLGREEN') 'Queue must require every grouped entry to pass.'
Assert-True ($queueRule[0].parameters.merge_method -eq 'SQUASH') 'Queue must use squash merging.'
Assert-True ($queueRule[0].parameters.max_entries_to_build -eq 1 -and $queueRule[0].parameters.max_entries_to_merge -eq 1) 'Queue must serialize build and merge to one entry.'

foreach ($path in @(
    '.github/workflows/ci.yml',
    '.github/workflows/validate-basecoat.yml',
    '.github/workflows/pr-validation.yml',
    '.github/workflows/agent-merge.yml'
)) {
    $content = Get-Content -LiteralPath $path -Raw
    Assert-True ($content -match '(?m)^\s{2}merge_group:\s*$') "$path must run on merge_group."
}
$agentWorkflow = Get-Content -LiteralPath '.github/workflows/agent-merge.yml' -Raw
Assert-True ($agentWorkflow -match '(?m)^\s{4}name:\s*Agent merge guardrails\s*$') 'Configured cloud-agent status context must match the actual workflow job name.'

Assert-True ($script -match '\[switch\]\$Apply' -and $script -match '\[switch\]\$Preflight' -and $script -match '\[switch\]\$Rollback') 'Deployment must expose explicit apply, read-only preflight, and rollback modes.'
Assert-True ($script -match 'ReadinessPrNumber = 3506' -and $script -match "state -ne 'MERGED'") 'Apply must require the readiness bootstrap PR to be merged.'
Assert-True ($script -match 'required_status_checks\.strict' -and $script -match 'missingExisting') 'Apply must preserve live strict protection and every existing required context.'
Assert-True ($script -match 'api.*repos/\$RepositorySlug/rulesets' -and $script -notmatch 'api.*orgs/') 'All ruleset writes must be repository-scoped, never organization-scoped.'
Assert-True ($script -match 'applied_fingerprint' -and $script -match 'Rollback refused: target ruleset changed') 'Rollback must refuse to overwrite post-apply ruleset changes.'
Assert-True ($script -match 'Agent merge guardrails' -and $script -match 'app_id -eq \$GitHubActionsAppId') 'Cloud-agent context must be checked against an actual GitHub Actions run.'
Assert-True ($script -notmatch 'merge_queue_posture -ne .required.') 'Queue apply must not require changing trusted policy-pack posture.'

Assert-True ($doc -match 'zero bypass actors' -and $doc -match 'read-only live preflight' -and $doc -match 'Rollback') 'Operator documentation must cover bypass, preflight, and rollback constraints.'
Assert-True ($doc -match 'Agent merge guardrails' -and $doc -match '15368') 'Operator documentation must identify the observed check context and app binding.'
Assert-True ($doc -match 'Organization- or enterprise-owned rulesets and branch protection are\s+never modified') 'Operator documentation must state inherited rules are not modified.'

. (Join-Path $repoRoot $scriptPath) -DryRun
$desired = Get-Content -LiteralPath $rulesetPath -Raw | ConvertFrom-Json -AsHashtable
$apiResponse = Get-Content -LiteralPath $rulesetPath -Raw | ConvertFrom-Json -AsHashtable
$apiResponse.Remove('description')
$apiResponse.id = 12345
$apiResponse.source = 'IBuySpy-Shared/basecoat'
$payload = Get-RulesetApiPayload $desired
Assert-True (-not $payload.Contains('description')) 'Ruleset API payload must exclude the unsupported description field.'
Assert-True ((Get-RulesetFingerprint $desired) -eq (Get-RulesetFingerprint $apiResponse)) 'GitHub response metadata and omitted description must not cause false verification failures.'
$apiResponse.rules[0].parameters.required_status_checks[0].context = 'different-required-check'
Assert-True ((Get-RulesetFingerprint $desired) -ne (Get-RulesetFingerprint $apiResponse)) 'Changing a required enforcement context must fail exact verification.'
$apiResponse = Get-Content -LiteralPath $rulesetPath -Raw | ConvertFrom-Json -AsHashtable
$apiResponse.bypass_actors = @(@{ actor_id = 1; actor_type = 'Team'; bypass_mode = 'always' })
Assert-True ((Get-RulesetFingerprint $desired) -ne (Get-RulesetFingerprint $apiResponse)) 'Adding a bypass actor must fail exact verification.'

Write-Host 'Native merge-queue activation contract tests passed.'

#Requires -Version 7.0
<#
.SYNOPSIS
  Parses the ship-it release-gate workflow's consolidated dispatch inputs and
  invokes release-gate-enforcer.ps1.

.DESCRIPTION
  ship-it-release-gate.yml consolidates its dispatch surface into three grouped
  key=value string inputs (workflow_dispatch caps at 10 inputs). This script is
  the single, testable seam that expands those grouped strings back into the
  enforcer's individual parameters, so the workflow and the test suite exercise
  identical parse/map logic.

  Grouped input formats (comma-separated key=value pairs):
    -GateStatus         lint,build,type,e2e,security,smoke
    -ArtifactStatus     spec,docs,tests,runbook,release_notes
    -PromotionContext   previous_stage,environment_protection,require_approval,
                        approval,rollback_validation,rollback_runbook_ref,goal_ids,
                        source_sha,spec_goals,docs_goals,tests_goals,runbook_goals,
                        release_notes_goals

  Values are split on the first '=' so URLs (rollback_runbook_ref) survive.
  goal_ids (and the per-artifact *_goals keys) use pipe ('|') separators to
  avoid colliding with the ',' record separator. Omitted keys fall back to
  sensible defaults; each per-artifact *_goals map defaults to goal_ids.
  Malformed tokens (missing '='), unknown keys, and duplicate keys are all
  rejected (fail closed). Supply source_sha for cross-branch/repo dispatch so
  the evidence bundle's immutable sha matches the promoted branch (defaults to
  the workflow GITHUB_SHA).
#>
[CmdletBinding()]
param(
  [string]$TargetRepo = '',
  [string]$TargetBranch = 'main',
  [string]$RiskBand = 'medium',
  [string]$PromotionStage = 'validate',
  [string]$ExecutionLane = 'standard',
  [string]$ChangeType = 'code',
  [string]$GateStatus = '',
  [string]$ArtifactStatus = '',
  [string]$PromotionContext = '',
  [string]$OutputPath = 'test-results/ship-it/promotion-evidence-bundle.json',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function ConvertFrom-KeyValueList([string]$Text, [string[]]$AllowedKeys) {
  $map = @{}
  if ([string]::IsNullOrWhiteSpace($Text)) { return $map }
  foreach ($pair in ($Text -split ',')) {
    $token = $pair.Trim()
    if (-not $token) { continue }
    $idx = $token.IndexOf('=')
    if ($idx -lt 1) {
      # Fail closed: a governance gate must not turn malformed dispatch input
      # (e.g. a missing '=' that would silently drop a status) into a pass.
      throw "Malformed grouped input token '$token'; expected 'key=value'."
    }
    $key = $token.Substring(0, $idx).Trim()
    if ($AllowedKeys -and ($AllowedKeys -notcontains $key)) {
      # Fail closed: an unknown key (typically a typo like 'doc=missing') would
      # otherwise leave the real key at its passing default and mask a block.
      throw "Unknown grouped input key '$key'; allowed keys: $($AllowedKeys -join ', ')."
    }
    if ($map.ContainsKey($key)) {
      throw "Duplicate grouped input key '$key'."
    }
    $map[$key] = $token.Substring($idx + 1).Trim()
  }
  return $map
}

function Get-OrDefault([hashtable]$Map, [string]$Key, [string]$Default) {
  if ($Map.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace($Map[$Key])) { return $Map[$Key] }
  return $Default
}

# Fail closed for enum status keys: default only when the key is ABSENT. A key
# that is present but empty (e.g. `spec=`) is passed through as an empty string
# so the enforcer's ValidateSet rejects it, instead of silently defaulting to a
# passing value. Value keys (goals, refs) keep the empty-is-default behavior.
function Get-StatusOrDefault([hashtable]$Map, [string]$Key, [string]$Default) {
  if ($Map.ContainsKey($Key)) { return $Map[$Key] }
  return $Default
}

$gates = ConvertFrom-KeyValueList $GateStatus -AllowedKeys @('lint', 'build', 'type', 'e2e', 'security', 'smoke')
$artifacts = ConvertFrom-KeyValueList $ArtifactStatus -AllowedKeys @('spec', 'docs', 'tests', 'runbook', 'release_notes')
$ctx = ConvertFrom-KeyValueList $PromotionContext -AllowedKeys @(
  'previous_stage', 'environment_protection', 'require_approval', 'approval',
  'rollback_validation', 'rollback_runbook_ref', 'goal_ids', 'source_sha',
  'spec_goals', 'docs_goals', 'tests_goals', 'runbook_goals', 'release_notes_goals'
)

$requireApproval = [System.Convert]::ToBoolean((Get-StatusOrDefault $ctx 'require_approval' 'false'))

# Each per-artifact goal map defaults to the contract-level goal_ids so the
# documented contract holds (the enforcer only applies this fallback to spec).
$contractGoalIds = Get-OrDefault $ctx 'goal_ids' ''

$enforcer = Join-Path $PSScriptRoot 'release-gate-enforcer.ps1'

& $enforcer `
  -TargetRepo $TargetRepo `
  -SourceBranch $TargetBranch `
  -SourceSha (Get-OrDefault $ctx 'source_sha' '') `
  -RiskBand $RiskBand `
  -PromotionStage $PromotionStage `
  -ExecutionLane $ExecutionLane `
  -ChangeType $ChangeType `
  -LintStatus (Get-StatusOrDefault $gates 'lint' 'not_run') `
  -BuildStatus (Get-StatusOrDefault $gates 'build' 'not_run') `
  -TypeStatus (Get-StatusOrDefault $gates 'type' 'not_run') `
  -E2eStatus (Get-StatusOrDefault $gates 'e2e' 'not_run') `
  -SecurityStatus (Get-StatusOrDefault $gates 'security' 'not_run') `
  -SmokeStatus (Get-StatusOrDefault $gates 'smoke' 'not_run') `
  -SpecStatus (Get-StatusOrDefault $artifacts 'spec' 'missing') `
  -DocsStatus (Get-StatusOrDefault $artifacts 'docs' 'missing') `
  -TestsStatus (Get-StatusOrDefault $artifacts 'tests' 'missing') `
  -RunbookStatus (Get-StatusOrDefault $artifacts 'runbook' 'missing') `
  -ReleaseNotesStatus (Get-StatusOrDefault $artifacts 'release_notes' 'missing') `
  -PreviousStageStatus (Get-StatusOrDefault $ctx 'previous_stage' 'not_run') `
  -EnvironmentProtectionStatus (Get-StatusOrDefault $ctx 'environment_protection' 'missing') `
  -RequireApproval $requireApproval `
  -ApprovalStatus (Get-StatusOrDefault $ctx 'approval' 'not-required') `
  -RollbackRunbookRef (Get-OrDefault $ctx 'rollback_runbook_ref' '') `
  -RollbackValidationStatus (Get-StatusOrDefault $ctx 'rollback_validation' 'missing') `
  -GoalIds $contractGoalIds `
  -SpecGoalIds (Get-OrDefault $ctx 'spec_goals' $contractGoalIds) `
  -DocsGoalIds (Get-OrDefault $ctx 'docs_goals' $contractGoalIds) `
  -TestsGoalIds (Get-OrDefault $ctx 'tests_goals' $contractGoalIds) `
  -RunbookGoalIds (Get-OrDefault $ctx 'runbook_goals' $contractGoalIds) `
  -ReleaseNotesGoalIds (Get-OrDefault $ctx 'release_notes_goals' $contractGoalIds) `
  -OutputPath $OutputPath `
  -DryRun:$DryRun

exit $LASTEXITCODE

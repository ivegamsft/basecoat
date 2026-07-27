[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\post-merge-release-chain.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\post-merge-release-chain.yml'

if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}
if (-not (Test-Path $templatePath)) {
    throw "Missing template workflow file: $templatePath"
}

$workflow = Get-Content -Path $workflowPath -Raw
$template = Get-Content -Path $templatePath -Raw

if ($workflow -ne $template) {
    throw 'post-merge-release-chain workflow and template must be identical.'
}

if ($workflow -notmatch '(?ms)pull_request:\s*\r?\n\s*branches:\s*\r?\n\s*-\s*main') {
    throw 'Workflow must trigger on pull_request closed events for main.'
}
if ($workflow -notmatch '(?m)types:\s*\r?\n\s*-\s*closed') {
    throw 'Workflow must filter pull_request trigger to closed type.'
}
if ($workflow -notmatch '(?m)workflow_dispatch:') {
    throw 'Workflow must support manual replay via workflow_dispatch.'
}
if ($workflow -notmatch '(?m)^permissions:\s*\r?\n\s*actions:\s*write\s*\r?\n\s*checks:\s*read\s*\r?\n\s*contents:\s*read\s*\r?\n\s*issues:\s*write\s*\r?\n\s*pull-requests:\s*write\s*\r?\n\s*statuses:\s*read') {
    throw 'Workflow permissions must include actions/contents/issues/pull-requests plus checks/statuses read.'
}
if ($workflow -notmatch 'ship-it-release-gate\.yml') {
    throw 'Workflow must dispatch ship-it-release-gate.yml after merge.'
}
if ($workflow -notmatch 'post-merge-release-chain:v1') {
    throw 'Workflow must include stable status marker for idempotent comments.'
}
if ($workflow -notmatch 'policy-packs\.json') {
    throw 'Workflow must load policy pack governance file.'
}
if ($workflow -notmatch 'required_approvals_by_risk_tier') {
    throw 'Workflow must derive approval policy from policy-pack risk tiers.'
}
if ($workflow -notmatch 'createWorkflowDispatch') {
    throw 'Workflow must invoke release gate via createWorkflowDispatch API.'
}
if ($workflow -notmatch 'package-basecoat\.yml') {
    throw 'Workflow must dispatch follow-up packaging workflow after release gate dispatch.'
}
if ($workflow -notmatch 'dispatch-failure') {
    throw 'Workflow must open remediation issue on dispatch failures.'
}
if ($workflow -notmatch 'checks\.listForRef') {
    throw 'Workflow must evaluate required checks from GitHub check runs for the validated PR SHA.'
}
if ($workflow -notmatch 'issues\.updateComment') {
    throw 'Workflow must upsert marker comments instead of always creating new comments.'
}
if ($workflow -match '✅|❌') {
    throw 'Workflow comments must not include emoji.'
}

# The release-gate dispatch payload must use only the consolidated inputs that
# ship-it-release-gate.yml declares (workflow_dispatch caps at 10 inputs). The
# removed per-field scalar names would be rejected by GitHub at dispatch time.
foreach ($groupedInput in @('gate_status:', 'artifact_status:', 'promotion_context:')) {
    if ($workflow -notmatch [regex]::Escape($groupedInput)) {
        throw "Workflow dispatch payload must construct grouped input '$groupedInput'."
    }
}
$removedScalarInputs = @(
    'lint_status:', 'build_status:', 'type_status:', 'security_status:',
    'smoke_status:', 'previous_stage_status:', 'environment_protection_status:',
    'approval_status:', 'rollback_validation_status:', 'spec_status:',
    'docs_status:', 'tests_status:', 'runbook_status:', 'release_notes_status:'
)
foreach ($removed in $removedScalarInputs) {
    if ($workflow -match [regex]::Escape($removed)) {
        throw "Workflow must not send removed release-gate scalar input '$removed'."
    }
}
# The post-merge gate is evidence-only: it must dispatch in dry-run mode so a
# blocked gate does not fail every merge (packaging is dispatched regardless).
if ($workflow -notmatch "dry_run:\s*'true'") {
    throw 'Post-merge release-gate dispatch must run in dry-run (evidence-only) mode.'
}

Write-Host 'Post-merge release chain workflow tests passed.'

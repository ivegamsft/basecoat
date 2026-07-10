[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\automation-stuck-state-watchdog.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\automation-stuck-state-watchdog.yml'
$configPath = Join-Path $repoRoot '.github\governance\automation-stage-slas.json'

if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}
if (-not (Test-Path $templatePath)) {
    throw "Missing template workflow file: $templatePath"
}
if (-not (Test-Path $configPath)) {
    throw "Missing SLA config file: $configPath"
}

$workflow = Get-Content -Path $workflowPath -Raw
$template = Get-Content -Path $templatePath -Raw
$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

if ($workflow -ne $template) {
    throw 'automation-stuck-state-watchdog workflow and template must be identical.'
}

if ($workflow -notmatch '(?m)name:\s*"BaseCoat - Automation Stuck-State Watchdog"') {
    throw 'Workflow must use the expected name.'
}
if ($workflow -notmatch '(?ms)schedule:\s*\r?\n\s*-\s*cron:\s*"15 \* \* \* \*"') {
    throw 'Workflow must run on the hourly watchdog schedule.'
}
if ($workflow -notmatch '(?m)workflow_dispatch:') {
    throw 'Workflow must support manual dispatch.'
}
if ($workflow -notmatch '(?m)timeout-minutes:\s*20') {
    throw 'Workflow job must set timeout-minutes to 20.'
}
if ($workflow -notmatch '(?m)group:\s*\$\{\{\s*github\.workflow\s*\}\}-\$\{\{\s*github\.ref\s*\}\}') {
    throw 'Workflow concurrency group must follow guardrail format.'
}
if ($workflow -notmatch '(?m)actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3') {
    throw 'Workflow must pin actions/github-script to the approved SHA.'
}
if ($workflow -notmatch '(?m)automation-watchdog:v1') {
    throw 'Workflow must use automation-watchdog marker for idempotent escalations.'
}
if ($workflow -notmatch '(?m)issue_to_pr' -or $workflow -notmatch '(?m)ready_to_merge' -or $workflow -notmatch '(?m)merge_to_release') {
    throw 'Workflow must evaluate all three SLA stages.'
}
if ($workflow -notmatch '(?m)watchdog:ignore' -or $workflow -notmatch '(?m)sla:exempt') {
    throw 'Workflow must support suppression labels to reduce false positives.'
}
if ($workflow -notmatch '(?m)\[Watchdog\]\[') {
    throw 'Workflow must open stage-specific remediation issues.'
}
if ($workflow -notmatch '(?m)\*\*Owner\*\*' -or $workflow -notmatch '(?m)\*\*Next action\*\*' -or $workflow -notmatch '(?m)\*\*Evidence\*\*') {
    throw 'Escalation records must include owner, next action, and evidence.'
}

if (-not $config.thresholds.issue_to_pr_hours -or -not $config.thresholds.ready_to_merge_hours -or -not $config.thresholds.merge_to_release_hours) {
    throw 'SLA config must define issue_to_pr_hours, ready_to_merge_hours, and merge_to_release_hours.'
}
if (-not $config.scan.lookback_days -or -not $config.scan.max_items) {
    throw 'SLA config must define lookback_days and max_items.'
}
if (-not ($config.suppression_labels -contains 'watchdog:ignore') -or -not ($config.suppression_labels -contains 'sla:exempt')) {
    throw 'SLA config must include suppression labels watchdog:ignore and sla:exempt.'
}

Write-Host 'Automation stuck-state watchdog tests passed.'

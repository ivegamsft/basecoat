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

# PRD-001 is present and enabled -> no finding.
# PRD-002 is present but disabled in the live project -> enabled-state drift.
# 'Untracked workflow' has no baseline entry -> extra drift.
$liveProject = [pscustomobject]@{
    workflows = [pscustomobject]@{
        nodes = @(
            [pscustomobject]@{
                name = $rule1.name
                enabled = $true
                triggers = @()
                actions = @()
            },
            [pscustomobject]@{
                name = $rule2.name
                enabled = $false
                triggers = @()
                actions = @()
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

# Condition/action signature drift is intentionally deferred, so no signature findings should appear.
$signatureDrift = $findings | Where-Object { $_.finding_id -like '*-modified-signature' }
if ($null -ne $signatureDrift) {
    throw 'Signature drift detection is deferred; no signature findings expected.'
}

$extraDrift = $findings | Where-Object { $_.drift_type -eq 'extra' }
if ($null -eq $extraDrift -or $extraDrift.rule_name -ne 'Untracked workflow') {
    throw 'Missing extra workflow drift finding.'
}

# A baseline rule with no matching live workflow -> missing drift.
$missingOnly = @(Compare-Rules -BaselineRules @($rule1) -LiveProject ([pscustomobject]@{
    workflows = [pscustomobject]@{ nodes = @() }
}))
if ($missingOnly.Count -ne 1 -or $missingOnly[0].finding_id -ne 'PRD-001-missing') {
    throw 'Expected a single PRD-001-missing finding when the live workflow is absent.'
}

# Regression for the by_drift_type count guard: under StrictMode a drift type with zero
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

Write-Host 'Project rules drift audit tests passed' -ForegroundColor Green
exit 0

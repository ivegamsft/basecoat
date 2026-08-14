[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$path = Join-Path $repoRoot '.github\governance\human-approval-boundaries.json'
$distributedPath = Join-Path $repoRoot '.github\base-coat\governance\human-approval-boundaries.json'
$policyPath = Join-Path $repoRoot '.github\governance\policy-packs.json'
$productionProtectionPath = Join-Path $repoRoot '.github\environment-protection-production.json'

foreach ($requiredPath in @($path, $distributedPath, $policyPath, $productionProtectionPath)) {
    if (-not (Test-Path $requiredPath)) {
        throw "Missing human approval contract file: $requiredPath"
    }
}

$json = Get-Content -Path $path -Raw | ConvertFrom-Json
$distributed = Get-Content -Path $distributedPath -Raw | ConvertFrom-Json
$policy = Get-Content -Path $policyPath -Raw | ConvertFrom-Json
$productionProtection = Get-Content -Path $productionProtectionPath -Raw | ConvertFrom-Json

if (($json | ConvertTo-Json -Depth 20) -ne ($distributed | ConvertTo-Json -Depth 20)) {
    throw 'Canonical and distributed human approval boundaries must remain identical.'
}

if ([string]::IsNullOrWhiteSpace($json.default_profile)) {
    throw 'human-approval-boundaries.json must define default_profile.'
}
if (-not $json.profiles) {
    throw 'human-approval-boundaries.json must define profiles.'
}
if (-not $json.profiles.$($json.default_profile)) {
    throw "Default profile '$($json.default_profile)' must exist in profiles."
}

$requiredAlways = @(
    'production_environment_approval',
    'policy_exception_override',
    'security_incident_override'
)
foreach ($gate in $requiredAlways) {
    if ($json.always_human_required -notcontains $gate) {
        throw "always_human_required must include '$gate'."
    }
}

$environmentContract = $json.production_environment_contract
if ($environmentContract.environment -ne $policy.production_environment.name) {
    throw 'Production environment names must match across policy and human approval contracts.'
}
if ($policy.production_environment.approval_boundary -ne 'production_environment_approval') {
    throw 'Policy must route production approval to production_environment_approval.'
}
if ($environmentContract.enforcement -ne 'github_environment' -or
    $environmentContract.minimum_required_reviewers -lt 1 -or
    $environmentContract.deployment_branch_policy -ne 'protected_or_selected' -or
    $environmentContract.deployment_workflow_binding_verification -ne 'pr_head_digest_and_environment_against_trusted_policy' -or
    $environmentContract.pr_approval_is_equivalent -ne $false -or
    $environmentContract.solo_dev_prevent_self_review -ne $false) {
    throw 'Production approval must be enforced by a protected GitHub environment, never by PR approval.'
}
if ($productionProtection.environment -ne $environmentContract.environment -or
    $productionProtection.protection_rules.require_deployment_approvals.enabled -ne $true -or
    $productionProtection.protection_rules.require_deployment_approvals.required_reviewers -lt
        $environmentContract.minimum_required_reviewers) {
    throw 'Production environment template must satisfy the human approval contract.'
}
if (-not $productionProtection.deployment_branch_policy.protected_branches -and
    -not $productionProtection.deployment_branch_policy.custom_branch_policies) {
    throw 'Production environment template must restrict deployment branches.'
}

$riskTiers = @('low', 'medium', 'high', 'critical')
foreach ($profileProperty in $json.profiles.PSObject.Properties) {
    $name = $profileProperty.Name
    $profile = $profileProperty.Value
    if ($null -eq $profile.issue_approval_signal_required) {
        throw "Profile '$name' must define issue_approval_signal_required."
    }
    if ($null -eq $profile.production_release_approval_required) {
        throw "Profile '$name' must define production_release_approval_required."
    }
    if ($null -eq $profile.maintainer_acknowledgement_satisfies_boundaries) {
        throw "Profile '$name' must define maintainer_acknowledgement_satisfies_boundaries."
    }
    foreach ($tier in $riskTiers) {
        if ($null -eq $profile.pr_approval_required_by_risk.$tier) {
            throw "Profile '$name' must define pr_approval_required_by_risk.$tier."
        }
        if ($null -eq $profile.maintainer_acknowledgement_required_by_risk.$tier) {
            throw "Profile '$name' must define maintainer_acknowledgement_required_by_risk.$tier."
        }
        $requiredApprovalCount = $policy.profiles.$name.main.required_approvals_by_risk_tier.$tier
        if ($profile.pr_approval_required_by_risk.$tier -ne ($requiredApprovalCount -gt 0)) {
            throw "Profile '$name' PR approval boundary disagrees with policy for risk tier '$tier'."
        }
        $policyAcknowledgement = $policy.profiles.$name.main.required_maintainer_acknowledgement_by_risk_tier.$tier
        if ($profile.maintainer_acknowledgement_required_by_risk.$tier -ne $policyAcknowledgement) {
            throw "Profile '$name' acknowledgement boundary disagrees with policy for risk tier '$tier'."
        }
    }
}

foreach ($tier in @('low', 'medium', 'high')) {
    if ($json.profiles.'solo-dev'.maintainer_acknowledgement_required_by_risk.$tier) {
        throw "Solo-dev routine tier '$tier' must not require maintainer acknowledgement."
    }
}
if (-not $json.profiles.'solo-dev'.maintainer_acknowledgement_required_by_risk.critical) {
    throw 'Solo-dev critical changes must require maintainer acknowledgement.'
}
foreach ($profileName in @('team-dev', 'regulated-team')) {
    if (@($json.profiles.$profileName.maintainer_acknowledgement_satisfies_boundaries).Count -ne 0) {
        throw "Profile '$profileName' must not replace always-human boundaries with maintainer acknowledgement."
    }
    foreach ($tier in $riskTiers) {
        if ($json.profiles.$profileName.maintainer_acknowledgement_required_by_risk.$tier) {
            throw "Profile '$profileName' must retain independent PR approvals instead of acknowledgement."
        }
    }
    foreach ($boundary in @('policy_exception_override', 'security_incident_override')) {
        if ($json.profiles.'solo-dev'.maintainer_acknowledgement_satisfies_boundaries -notcontains $boundary) {
            throw "Solo-dev must allow maintainer acknowledgement for '$boundary'."
        }
    }
}

Write-Host 'Human approval boundaries policy tests passed.'

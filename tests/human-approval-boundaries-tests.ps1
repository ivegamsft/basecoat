[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$path = Join-Path $repoRoot '.github\governance\human-approval-boundaries.json'

if (-not (Test-Path $path)) {
    throw "Missing human approval boundaries policy file: $path"
}

$json = Get-Content -Path $path -Raw | ConvertFrom-Json

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
    foreach ($tier in $riskTiers) {
        if ($null -eq $profile.pr_approval_required_by_risk.$tier) {
            throw "Profile '$name' must define pr_approval_required_by_risk.$tier."
        }
    }
}

Write-Host 'Human approval boundaries policy tests passed.'

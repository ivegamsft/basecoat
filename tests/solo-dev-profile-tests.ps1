[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$guidePath = Join-Path $repoRoot 'docs\guides\solo-dev-profile.md'
$mkdocsPath = Join-Path $repoRoot 'mkdocs.yml'
$contractPath = Join-Path $repoRoot 'docs\reference\onboarding-profile-contract.v1.md'
$policyPath = Join-Path $repoRoot '.github\governance\policy-packs.json'
$distributedPolicyPath = Join-Path $repoRoot '.github\base-coat\governance\policy-packs.json'
$installerPath = Join-Path $repoRoot 'scripts\configure-downstream-workflows.ps1'
$bootstrapPath = Join-Path $repoRoot 'scripts\bootstrap.ps1'

foreach ($path in @(
    $guidePath,
    $mkdocsPath,
    $contractPath,
    $policyPath,
    $distributedPolicyPath,
    $installerPath,
    $bootstrapPath
)) {
    if (-not (Test-Path $path)) {
        throw "Missing solo-dev profile contract surface: $path"
    }
}

$guide = Get-Content -Path $guidePath -Raw
$mkdocs = Get-Content -Path $mkdocsPath -Raw
$contract = Get-Content -Path $contractPath -Raw
$policy = Get-Content -Path $policyPath -Raw | ConvertFrom-Json
$distributedPolicy = Get-Content -Path $distributedPolicyPath -Raw | ConvertFrom-Json

foreach ($requiredText in @(
    'never `--admin`',
    'required status checks',
    'Self-merge policy',
    'Rollback',
    'Transition to a stronger profile',
    'BASECOAT_POLICY_PACK',
    'pr-auto-merge-executor.yml',
    'bypass list is empty',
    'BaseCoat merge eligibility',
    '"allowed_merge_methods": ["squash"]',
    '-Workflow pr-auto-merge-executor.yml',
    'Read repository contents and packages permissions'
)) {
    if ($guide -notmatch [regex]::Escape($requiredText)) {
        throw "Solo-dev guide is missing required guidance: $requiredText"
    }
    if ($guide -match 'select \*\*Read and write permissions\*\*') {
        throw 'Solo-dev guidance must not enable repository-wide workflow write permissions.'
    }

    $rulesetMatch = [regex]::Match(
        $guide,
        'Create `solo-dev-main-ruleset\.json`:\s*```json\s*(?<payload>\{.*?\})\s*```',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $rulesetMatch.Success) {
        throw 'Solo-dev guide must include a parseable ruleset payload.'
    }
    $rulesetPayload = $rulesetMatch.Groups['payload'].Value | ConvertFrom-Json
    $pullRequestRule = $rulesetPayload.rules | Where-Object { $_.type -eq 'pull_request' }
    if ($pullRequestRule.parameters.allowed_merge_methods -notcontains 'squash') {
        throw 'Solo-dev ruleset must allow the squash method used by the executor.'
    }
    if ($pullRequestRule.parameters.required_approving_review_count -ne 1 -or
        $pullRequestRule.parameters.require_last_push_approval -ne $true) {
        throw 'Portable solo-dev ruleset must enforce one independent approval after the last push.'
    }
    $requiredStatusRule = $rulesetPayload.rules | Where-Object { $_.type -eq 'required_status_checks' }
    $requiredStatusChecks = @($requiredStatusRule.parameters.required_status_checks)
    $requiredContexts = @($requiredStatusChecks.context)
    if ($requiredContexts -notcontains 'BaseCoat merge eligibility') {
        throw 'Solo-dev ruleset must require the failing merge eligibility gate.'
    }
    $untrustedStatusChecks = @($requiredStatusChecks | Where-Object { $_.integration_id -ne 15368 })
    if ($untrustedStatusChecks.Count -gt 0) {
        throw 'Solo-dev ruleset must pin required contexts to the GitHub Actions integration.'
    }
}

if ($mkdocs -notmatch 'Solo-Developer Profile:\s+guides/solo-dev-profile\.md') {
    throw 'Solo-dev guide must be discoverable in mkdocs navigation.'
}
if ($contract -notmatch 'Solo-Developer Governance Profile') {
    throw 'Onboarding profile contract must link to the solo-dev implementation guide.'
}
if ($policy.default_profile -ne 'solo-dev') {
    throw 'Canonical governance policy must keep the shipped solo-dev default explicit.'
}
if (($policy | ConvertTo-Json -Depth 20) -ne ($distributedPolicy | ConvertTo-Json -Depth 20)) {
    throw 'Canonical and distributed governance policy packs must remain identical.'
}
foreach ($riskTier in @('low', 'medium', 'high', 'critical')) {
    if ($policy.profiles.'solo-dev'.main.required_approvals_by_risk_tier.$riskTier -ne 1) {
        throw "Portable solo-dev policy must require one independent approval for $riskTier risk."
    }
}
foreach ($productionPath in @(
    '.github/workflows/close-production-issues.yml',
    '.github/workflows/docs-production.yml',
    '.github/workflows/extension-deploy.yml',
    '.github/workflows/mcp-deploy.yml',
    '.github/workflows/publish-to-production.yml'
)) {
    if ($policy.production_release_paths -notcontains $productionPath) {
        throw "Policy must retain human approval for production path: $productionPath"
    }
}
$productionCapableWorkflows = Get-ChildItem -Path (Join-Path $repoRoot '.github\workflows') -Filter '*.yml' |
    Where-Object {
        (Get-Content -Path $_.FullName -Raw) -match '(?m)^\s*environment:\s*.*production'
    }
foreach ($productionWorkflow in $productionCapableWorkflows) {
    $productionPath = ".github/workflows/$($productionWorkflow.Name)"
    if ($policy.production_release_paths -notcontains $productionPath) {
        throw "Production-capable workflow must be governed by production_release_paths: $productionPath"
    }
}

$scratchRoot = Join-Path $repoRoot 'test-results\solo-dev-profile-contract'
$workflowDestination = Join-Path $scratchRoot 'workflows'
$governanceDestination = Join-Path $scratchRoot 'governance'
$blockedContractPath = Join-Path $scratchRoot 'blocked-downgrade.json'
$allowedContractPath = Join-Path $scratchRoot 'allowed-downgrade.json'
$upgradeContractPath = Join-Path $scratchRoot 'upgrade.json'
$initialContractPath = Join-Path $scratchRoot 'initial-profile.json'
$malformedContractPath = Join-Path $scratchRoot 'malformed.json'
$invalidSchemaContractPath = Join-Path $scratchRoot 'missing-profile.json'
$lfBootstrapPath = Join-Path $scratchRoot 'bootstrap-lf.ps1'

try {
    if (Test-Path $scratchRoot) {
        Remove-Item -Path $scratchRoot -Recurse -Force
    }
    New-Item -Path $workflowDestination -ItemType Directory -Force | Out-Null
    New-Item -Path $governanceDestination -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path $workflowDestination 'basecoat-consumer-owned.yml') -Value 'name: Consumer owned'

    & pwsh -NoProfile -File $installerPath `
        -Workflow 'pr-auto-merge-executor.yml' `
        -KeepUnknownBc `
        -DestinationDir $workflowDestination `
        -GovernanceDestinationDir $governanceDestination
    if ($LASTEXITCODE -ne 0) {
        throw 'Targeted workflow installation failed.'
    }

    foreach ($expectedPath in @(
        (Join-Path $workflowDestination 'basecoat-pr-auto-merge-executor.yml'),
        (Join-Path $workflowDestination 'basecoat-consumer-owned.yml'),
        (Join-Path $governanceDestination 'policy-packs.json'),
        (Join-Path $governanceDestination 'human-approval-boundaries.json')
    )) {
        if (-not (Test-Path $expectedPath)) {
            throw "Targeted workflow installation did not preserve or install: $expectedPath"
        }
    }

    $installedPolicyPath = Join-Path $governanceDestination 'policy-packs.json'
    $installedBoundaryPath = Join-Path $governanceDestination 'human-approval-boundaries.json'
    $consumerPolicy = Get-Content -Path $installedPolicyPath -Raw | ConvertFrom-Json
    $consumerPolicy.production_release_paths += '.github/workflows/deploy.yml'
    Set-Content -Path $installedPolicyPath -NoNewline -Encoding UTF8 -Value (
        $consumerPolicy | ConvertTo-Json -Depth 20
    )
    $consumerBoundaries = Get-Content -Path $installedBoundaryPath -Raw | ConvertFrom-Json
    $consumerBoundaries | Add-Member -NotePropertyName consumer_customization -NotePropertyValue $true
    Set-Content -Path $installedBoundaryPath -NoNewline -Encoding UTF8 -Value (
        $consumerBoundaries | ConvertTo-Json -Depth 20
    )
    $policyBeforeReinstall = Get-Content -Path $installedPolicyPath -Raw
    $boundariesBeforeReinstall = Get-Content -Path $installedBoundaryPath -Raw

    & pwsh -NoProfile -File $installerPath `
        -Workflow 'pr-auto-merge-executor.yml' `
        -KeepUnknownBc `
        -DestinationDir $workflowDestination `
        -GovernanceDestinationDir $governanceDestination
    if ($LASTEXITCODE -ne 0) {
        throw 'Targeted workflow reinstallation failed.'
    }
    if ((Get-Content -Path $installedPolicyPath -Raw) -ne $policyBeforeReinstall -or
        (Get-Content -Path $installedBoundaryPath -Raw) -ne $boundariesBeforeReinstall) {
        throw 'Targeted workflow reinstallation must preserve consumer governance customizations.'
    }

    $unexpectedWorkflows = @(
        Get-ChildItem -Path $workflowDestination -Filter '*.yml' -File |
            Where-Object {
                $_.Name -notin @(
                    'basecoat-pr-auto-merge-executor.yml',
                    'basecoat-consumer-owned.yml'
                )
            }
    )
    if ($unexpectedWorkflows.Count -gt 0) {
        throw "Targeted installation copied unrelated workflows: $($unexpectedWorkflows.Name -join ', ')"
    }

    Set-Content -Path $blockedContractPath -NoNewline -Value @'
{"contract_version":"1.0.0","profile":"solo-dev","migration_from":"team-dev","allow_profile_downgrade":false}
'@
    Set-Content -Path $allowedContractPath -NoNewline -Value @'
{"contract_version":"1.0.0","profile":"solo-dev","migration_from":"team-dev","allow_profile_downgrade":true}
'@
    Set-Content -Path $upgradeContractPath -NoNewline -Value @'
{"contract_version":"1.0.0","profile":"team-dev","migration_from":"solo-dev","allow_profile_downgrade":false}
'@
    Set-Content -Path $initialContractPath -NoNewline -Value @'
{"contract_version":"1.0.0","profile":"solo-dev","allow_profile_downgrade":false}
'@
    Set-Content -Path $malformedContractPath -NoNewline -Value '{"contract_version":'
    Set-Content -Path $invalidSchemaContractPath -NoNewline -Value '{"contract_version":"1.0.0"}'
    $bootstrapContent = [System.IO.File]::ReadAllText($bootstrapPath) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText(
        $lfBootstrapPath,
        $bootstrapContent,
        [System.Text.UTF8Encoding]::new($false)
    )

    & pwsh -NoProfile -File $bootstrapPath `
        -OnboardingContractPath $blockedContractPath `
        -ValidateProfileOnly 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        throw 'Bootstrap must reject an unapproved team-dev to solo-dev downgrade.'
    }

    & pwsh -NoProfile -File $bootstrapPath `
        -OnboardingContractPath $malformedContractPath `
        -ValidateProfileOnly 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        throw 'Profile-only validation must reject malformed onboarding contract JSON.'
    }

    & pwsh -NoProfile -File $bootstrapPath `
        -OnboardingContractPath $invalidSchemaContractPath `
        -ValidateProfileOnly 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        throw 'Profile-only validation must reject a contract missing the profile field.'
    }

    $allowedOutput = & pwsh -NoProfile -File $bootstrapPath `
        -OnboardingContractPath $allowedContractPath `
        -ValidateProfileOnly
    if ($LASTEXITCODE -ne 0 -or ($allowedOutput | ConvertFrom-Json).profile -ne 'solo-dev') {
        throw 'Bootstrap must allow an explicitly approved profile downgrade.'
    }

    $upgradeOutput = & pwsh -NoProfile -File $bootstrapPath `
        -OnboardingContractPath $upgradeContractPath `
        -ValidateProfileOnly
    if ($LASTEXITCODE -ne 0 -or ($upgradeOutput | ConvertFrom-Json).profile -ne 'team-dev') {
        throw 'Bootstrap must allow a stronger profile transition.'
    }

    $initialOutput = & pwsh -NoProfile -File $lfBootstrapPath `
        -OnboardingContractPath $initialContractPath `
        -ValidateProfileOnly
    if ($LASTEXITCODE -ne 0 -or ($initialOutput | ConvertFrom-Json).profile -ne 'solo-dev') {
        throw 'Bootstrap must accept an initial contract that omits optional migration_from.'
    }
} finally {
    if (Test-Path $scratchRoot) {
        Remove-Item -Path $scratchRoot -Recurse -Force
    }
}

Write-Host 'Solo-dev profile guidance tests passed.'

[CmdletBinding()]
param()

# Contract test for scripts/bootstrap.ps1's Get-OnboardingSecretVariableRequirements.
#
# The function is pure (no I/O, no side effects) so it is extracted from
# bootstrap.ps1 by source text and dot-sourced in isolation, then exercised
# with the true/false combinations that matter for the workflow-conditional
# secret requirements. This guards against future changes silently dropping a
# requirement, gating it on the wrong flag, or gating it on profile when it
# must not be.

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$bootstrapPath = Join-Path $repoRoot 'scripts\bootstrap.ps1'
$bootstrapText = [System.IO.File]::ReadAllText($bootstrapPath) -replace "`r`n", "`n"

$functionMatch = [regex]::Match(
    $bootstrapText,
    '(?ms)^function Get-OnboardingSecretVariableRequirements\(.*?^\}\r?$'
)
if (-not $functionMatch.Success) {
    throw 'Could not locate Get-OnboardingSecretVariableRequirements in scripts/bootstrap.ps1 -- has it been renamed or restructured?'
}
$workflowDetectorMatch = [regex]::Match(
    $bootstrapText,
    '(?ms)^function Test-OnboardingMergeExecutorWorkflow\s*\{.*?^\}\r?$'
)
if (-not $workflowDetectorMatch.Success) {
    throw 'Could not locate Test-OnboardingMergeExecutorWorkflow in scripts/bootstrap.ps1 -- has it been renamed or restructured?'
}

$tempMarkerPath = [System.IO.Path]::GetTempFileName()
$extractedFunctionPath = "$tempMarkerPath.ps1"
Remove-Item -Path $tempMarkerPath -Force -ErrorAction SilentlyContinue
try {
    Set-Content -Path $extractedFunctionPath -Value "$($workflowDetectorMatch.Value)`n`n$($functionMatch.Value)" -NoNewline
    . $extractedFunctionPath

    function Assert-RequirementPresence {
        param(
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][string]$Case,
            [Parameter(Mandatory = $true)][bool]$Expected,
            [AllowNull()][object[]]$Requirements
        )
        $present = [bool]($Requirements | Where-Object { $_.Name -eq $Name })
        if ($present -ne $Expected) {
            throw "$Case`: expected $Name presence=$Expected but got $present."
        }
    }

    $soloProfile = [pscustomobject]@{ profile = 'solo-dev'; secrets_mode = 'checked-in' }
    $teamProfile = [pscustomobject]@{ profile = 'team-dev'; secrets_mode = 'checked-in' }
    $regulatedProfile = [pscustomobject]@{ profile = 'regulated-team'; secrets_mode = 'org-managed' }

    # PRODUCTION_REPO_TOKEN is workflow-file-gated, not profile-gated --
    # solo-dev must still require it when the publish workflow exists.
    foreach ($profile in @($soloProfile, $teamProfile, $regulatedProfile)) {
        $reqsNoWorkflows = Get-OnboardingSecretVariableRequirements `
            -profileSelection $profile -hasPublishWorkflow $false `
            -hasMergeExecutorWorkflow $false `
            -hasPortalDeployWorkflow $false
        Assert-RequirementPresence -Name 'PRODUCTION_REPO_TOKEN' -Case "$($profile.profile)/no publish workflow" -Expected $false -Requirements $reqsNoWorkflows
        Assert-RequirementPresence -Name 'BASECOAT_RELEASE_AUDIT_TOKEN' -Case "$($profile.profile)/no publish workflow" -Expected $false -Requirements $reqsNoWorkflows
        Assert-RequirementPresence -Name 'BASECOAT_MERGE_QUEUE_TOKEN' -Case "$($profile.profile)/no merge executor" -Expected $false -Requirements $reqsNoWorkflows

        $reqsWithWorkflows = Get-OnboardingSecretVariableRequirements `
            -profileSelection $profile -hasPublishWorkflow $true `
            -hasMergeExecutorWorkflow $true `
            -hasPortalDeployWorkflow $false
        Assert-RequirementPresence -Name 'PRODUCTION_REPO_TOKEN' -Case "$($profile.profile)/publish workflow present" -Expected $true -Requirements $reqsWithWorkflows
        Assert-RequirementPresence -Name 'BASECOAT_RELEASE_AUDIT_TOKEN' -Case "$($profile.profile)/publish workflow present" -Expected $false -Requirements $reqsWithWorkflows
        Assert-RequirementPresence -Name 'BASECOAT_MERGE_QUEUE_TOKEN' -Case "$($profile.profile)/merge executor present" -Expected $true -Requirements $reqsWithWorkflows
    }

    # GH_AW_GITHUB_MCP_SERVER_TOKEN remains profile-gated (org-managed secrets_mode only).
    $regulatedReqs = Get-OnboardingSecretVariableRequirements `
        -profileSelection $regulatedProfile -hasPublishWorkflow $false `
        -hasMergeExecutorWorkflow $false `
        -hasPortalDeployWorkflow $false
    Assert-RequirementPresence -Name 'GH_AW_GITHUB_MCP_SERVER_TOKEN' -Case 'regulated-team org-managed secrets' -Expected $true -Requirements $regulatedReqs

    $soloReqs = Get-OnboardingSecretVariableRequirements `
        -profileSelection $soloProfile -hasPublishWorkflow $false `
        -hasMergeExecutorWorkflow $false `
        -hasPortalDeployWorkflow $false
    Assert-RequirementPresence -Name 'GH_AW_GITHUB_MCP_SERVER_TOKEN' -Case 'solo-dev checked-in secrets' -Expected $false -Requirements $soloReqs

    $workflowDetectionRoot = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-merge-executor-detection-$([guid]::NewGuid().ToString('N'))"
    $workflowDetectionDirectory = Join-Path $workflowDetectionRoot '.github\workflows'
    $workflowDetectionGithubDirectory = Join-Path $workflowDetectionRoot '.github'
    $workflowNames = @(
        'pr-auto-merge-executor.yml',
        'basecoat-pr-auto-merge-executor.yml'
    )
    New-Item -ItemType Directory -Path $workflowDetectionDirectory -Force | Out-Null
    try {
        if (Test-OnboardingMergeExecutorWorkflow -RepositoryRoot $workflowDetectionRoot) {
            throw 'Workflow detector must return false when neither executor filename is installed.'
        }

        foreach ($workflowName in $workflowNames) {
            $workflowPath = Join-Path $workflowDetectionDirectory $workflowName
            Set-Content -LiteralPath $workflowPath -Value 'name: test' -NoNewline
            if (-not (Test-OnboardingMergeExecutorWorkflow -RepositoryRoot $workflowDetectionRoot)) {
                throw "Workflow detector did not recognize $workflowName."
            }

            $detectedRequirements = Get-OnboardingSecretVariableRequirements `
                -profileSelection $soloProfile -hasPublishWorkflow $false `
                -hasMergeExecutorWorkflow (Test-OnboardingMergeExecutorWorkflow -RepositoryRoot $workflowDetectionRoot) `
                -hasPortalDeployWorkflow $false
            Assert-RequirementPresence -Name 'BASECOAT_MERGE_QUEUE_TOKEN' -Case "$workflowName installed" -Expected $true -Requirements $detectedRequirements
            Remove-Item -LiteralPath $workflowPath -Force
        }

        Write-Host 'PASS merge-queue secret detection for source and downstream-installed executor filenames.'
    } finally {
        foreach ($workflowName in $workflowNames) {
            Remove-Item -LiteralPath (Join-Path $workflowDetectionDirectory $workflowName) -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $workflowDetectionDirectory -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $workflowDetectionGithubDirectory -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $workflowDetectionRoot -Force -ErrorAction SilentlyContinue
    }

    Write-Host 'PASS Get-OnboardingSecretVariableRequirements gates workflow-specific secrets across solo-dev/team-dev/regulated-team.'
} finally {
    Remove-Item -Path $extractedFunctionPath -Force -ErrorAction SilentlyContinue
}

Write-Host 'All bootstrap secret-requirement contract tests passed'

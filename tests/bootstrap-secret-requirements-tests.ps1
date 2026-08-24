[CmdletBinding()]
param()

# Contract test for scripts/bootstrap.ps1's Get-OnboardingSecretVariableRequirements.
#
# The function is pure (no I/O, no side effects) so it is extracted from
# bootstrap.ps1 by source text and dot-sourced in isolation, then exercised
# with the true/false combinations that matter for the workflow-conditional
# secret requirements (PRODUCTION_REPO_TOKEN, BASECOAT_RELEASE_AUDIT_TOKEN).
# This guards against future changes silently dropping a requirement, gating
# it on the wrong flag, or gating it on profile when it must not be.

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

$tempMarkerPath = [System.IO.Path]::GetTempFileName()
$extractedFunctionPath = "$tempMarkerPath.ps1"
Remove-Item -Path $tempMarkerPath -Force -ErrorAction SilentlyContinue
try {
    Set-Content -Path $extractedFunctionPath -Value $functionMatch.Value -NoNewline
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

    # PRODUCTION_REPO_TOKEN and BASECOAT_RELEASE_AUDIT_TOKEN are workflow-file-gated,
    # not profile-gated -- solo-dev must still require them when the workflow exists.
    foreach ($profile in @($soloProfile, $teamProfile, $regulatedProfile)) {
        $reqsNoWorkflows = Get-OnboardingSecretVariableRequirements `
            -profileSelection $profile -hasPublishWorkflow $false `
            -hasPortalDeployWorkflow $false -hasReleaseWorkflow $false
        Assert-RequirementPresence -Name 'PRODUCTION_REPO_TOKEN' -Case "$($profile.profile)/no publish workflow" -Expected $false -Requirements $reqsNoWorkflows
        Assert-RequirementPresence -Name 'BASECOAT_RELEASE_AUDIT_TOKEN' -Case "$($profile.profile)/no release workflow" -Expected $false -Requirements $reqsNoWorkflows

        $reqsWithWorkflows = Get-OnboardingSecretVariableRequirements `
            -profileSelection $profile -hasPublishWorkflow $true `
            -hasPortalDeployWorkflow $false -hasReleaseWorkflow $true
        Assert-RequirementPresence -Name 'PRODUCTION_REPO_TOKEN' -Case "$($profile.profile)/publish workflow present" -Expected $true -Requirements $reqsWithWorkflows
        Assert-RequirementPresence -Name 'BASECOAT_RELEASE_AUDIT_TOKEN' -Case "$($profile.profile)/release workflow present" -Expected $true -Requirements $reqsWithWorkflows
    }

    # hasReleaseWorkflow must be honored as a single flag representing either
    # release.yml or package-basecoat.yml -- the caller in bootstrap.ps1 ORs
    # both Test-Path checks together before calling this function, so the
    # function itself only needs to prove it reacts to the flag correctly.
    $reqsReleaseOnly = Get-OnboardingSecretVariableRequirements `
        -profileSelection $teamProfile -hasPublishWorkflow $false `
        -hasPortalDeployWorkflow $false -hasReleaseWorkflow $true
    Assert-RequirementPresence -Name 'BASECOAT_RELEASE_AUDIT_TOKEN' -Case 'release workflow flag true' -Expected $true -Requirements $reqsReleaseOnly

    $reqsReleaseAbsent = Get-OnboardingSecretVariableRequirements `
        -profileSelection $teamProfile -hasPublishWorkflow $false `
        -hasPortalDeployWorkflow $false -hasReleaseWorkflow $false
    Assert-RequirementPresence -Name 'BASECOAT_RELEASE_AUDIT_TOKEN' -Case 'release workflow flag false' -Expected $false -Requirements $reqsReleaseAbsent

    # GH_AW_GITHUB_MCP_SERVER_TOKEN remains profile-gated (org-managed secrets_mode only).
    $regulatedReqs = Get-OnboardingSecretVariableRequirements `
        -profileSelection $regulatedProfile -hasPublishWorkflow $false `
        -hasPortalDeployWorkflow $false -hasReleaseWorkflow $false
    Assert-RequirementPresence -Name 'GH_AW_GITHUB_MCP_SERVER_TOKEN' -Case 'regulated-team org-managed secrets' -Expected $true -Requirements $regulatedReqs

    $soloReqs = Get-OnboardingSecretVariableRequirements `
        -profileSelection $soloProfile -hasPublishWorkflow $false `
        -hasPortalDeployWorkflow $false -hasReleaseWorkflow $false
    Assert-RequirementPresence -Name 'GH_AW_GITHUB_MCP_SERVER_TOKEN' -Case 'solo-dev checked-in secrets' -Expected $false -Requirements $soloReqs

    Write-Host 'PASS Get-OnboardingSecretVariableRequirements gates PRODUCTION_REPO_TOKEN and BASECOAT_RELEASE_AUDIT_TOKEN on workflow presence (not profile), across solo-dev/team-dev/regulated-team.'
} finally {
    Remove-Item -Path $extractedFunctionPath -Force -ErrorAction SilentlyContinue
}

Write-Host 'All bootstrap secret-requirement contract tests passed'

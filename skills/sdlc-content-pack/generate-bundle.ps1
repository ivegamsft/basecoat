#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $true)]
    [string]$BundleId,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("plan", "build", "validate", "rollout", "operate")]
    [string]$SdlcPhase,

    [Parameter(Mandatory = $true)]
    [string]$Audience,

    [Parameter(Mandatory = $true)]
    [ValidateSet("draft", "pilot", "standardized", "production-ready")]
    [string]$Maturity,

    [string[]]$ArtifactTypes = @("diagram", "click-through", "video-script", "deck"),
    [string[]]$Constraints = @(),
    [string[]]$SourceRefs = @(),
    [Parameter(Mandatory = $true)]
    [string[]]$WorkflowSteps,
    [string]$DomainOverlay = "baseline"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-ListToBullets {
    param([string[]]$Values)

    if ($Values.Count -eq 0) {
        return "- None provided"
    }

    return (($Values | ForEach-Object { "- $_" }) -join "`n")
}

function Resolve-StepValue {
    param(
        [string[]]$Steps,
        [int]$Index
    )

    if ($Index -lt $Steps.Count) {
        return $Steps[$Index]
    }

    return "Additional review step"
}

function Apply-Template {
    param(
        [string]$TemplatePath,
        [string]$DestinationPath,
        [hashtable]$Tokens
    )

    if (-not (Test-Path $TemplatePath)) {
        Write-Error "Template not found: $TemplatePath"
        exit 1
    }

    $content = Get-Content -Path $TemplatePath -Raw

    foreach ($key in $Tokens.Keys) {
        $pattern = [Regex]::Escape("{{${key}}}")
        $content = [Regex]::Replace($content, $pattern, [string]$Tokens[$key])
    }

    Set-Content -Path $DestinationPath -Value $content
}

$skillRoot = $PSScriptRoot
$templateRoot = Join-Path $skillRoot "templates"
$bundleRoot = Join-Path (Resolve-Path $OutputPath).Path $BundleId
$WorkflowSteps = @($WorkflowSteps | Where-Object { $_ -and $_.Trim() })

if (@($WorkflowSteps).Count -lt 4) {
    Write-Error "At least four workflow steps are required to generate a consistent bundle."
    exit 1
}

New-Item -ItemType Directory -Path $bundleRoot -Force | Out-Null

$constraintsText = if ($Constraints.Count -gt 0) { $Constraints -join ", " } else { "None provided" }
$sourceRefsText = Convert-ListToBullets -Values $SourceRefs
$workflowSummary = "This bundle explains the $SdlcPhase workflow for $Audience teams at $Maturity maturity."
$handoffSummary = "Handoff completes when the next owner receives the validated bundle, source references, and decision record."

$tokens = @{
    bundle_id = $BundleId
    sdlc_phase = $SdlcPhase
    audience = $Audience
    maturity = $Maturity
    constraints = $constraintsText
    domain_overlay = $DomainOverlay
    source_refs = $sourceRefsText
    workflow_summary = $workflowSummary
    handoff_summary = $handoffSummary
    decision_point_1 = "Confirm the workflow evidence is ready for $Audience review."
    decision_point_2 = "Approve the handoff package before the next SDLC phase starts."
    entry_signal = "Bundle request approved"
    exit_signal = "Bundle package exported and reviewed"
    opening_hook = "In this short walkthrough, we will show how the $SdlcPhase flow moves from request to handoff."
    step_1 = (Resolve-StepValue -Steps $WorkflowSteps -Index 0)
    step_2 = (Resolve-StepValue -Steps $WorkflowSteps -Index 1)
    step_3 = (Resolve-StepValue -Steps $WorkflowSteps -Index 2)
    step_4 = (Resolve-StepValue -Steps $WorkflowSteps -Index 3)
    step_5 = (Resolve-StepValue -Steps $WorkflowSteps -Index 4)
    step_1_detail = "Explain the context, trigger, and owner for this first workflow step."
    step_2_detail = "Describe the main action, artifact, or decision produced here."
    step_3_detail = "Show the review, validation, or collaboration point for the step."
    step_4_detail = "Capture how evidence, approvals, or refinements are handled."
    step_5_detail = "Close with the receiving team, next action, and expected handoff result."
}

$artifactMap = @{
    "diagram" = @{
        template = Join-Path $templateRoot "diagram-template.md"
        output = "diagram.md"
    }
    "click-through" = @{
        template = Join-Path $templateRoot "click-through-template.md"
        output = "click-through.md"
    }
    "video-script" = @{
        template = Join-Path $templateRoot "video-script-template.md"
        output = "video-script.md"
    }
    "deck" = @{
        template = Join-Path $templateRoot "deck-template.md"
        output = "deck.md"
    }
}

$generatedArtifacts = @()

foreach ($artifactType in $ArtifactTypes) {
    if (-not $artifactMap.ContainsKey($artifactType)) {
        Write-Error "Unsupported artifact type: $artifactType"
        exit 1
    }

    $destinationPath = Join-Path $bundleRoot $artifactMap[$artifactType].output
    Apply-Template -TemplatePath $artifactMap[$artifactType].template -DestinationPath $destinationPath -Tokens $tokens
    $generatedArtifacts += $artifactMap[$artifactType].output
}

$manifest = @{
    bundle_id = $BundleId
    artifact_types = $ArtifactTypes
    sdlc_phase = $SdlcPhase
    audience = $Audience
    maturity = $Maturity
    constraints = $Constraints
    source_refs = $SourceRefs
    domain_overlay = $DomainOverlay
    workflow_steps = $WorkflowSteps
    generated_files = $generatedArtifacts
    generated_at = (Get-Date).ToString("o")
}

$qualityReport = @{
    bundle_id = $BundleId
    checks = @{
        requested_artifacts_generated = ($generatedArtifacts.Count -eq $ArtifactTypes.Count)
        workflow_steps_present = ($WorkflowSteps.Count -ge 4)
        source_refs_present = ($SourceRefs.Count -gt 0)
        handoff_summary_present = $true
    }
    rubric_status = "human-review-required"
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $bundleRoot "manifest.json")
$qualityReport | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $bundleRoot "quality-report.json")

[pscustomobject]@{
    bundle_root = $bundleRoot
    generated_files = $generatedArtifacts + @("manifest.json", "quality-report.json")
    workflow_steps = $WorkflowSteps
}

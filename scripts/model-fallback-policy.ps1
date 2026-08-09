#!/usr/bin/env pwsh

$script:ModelCapabilityCatalogPath = Join-Path (Split-Path -Parent $PSScriptRoot) "docs/reference/model-capabilities.json"
$script:ModelCapabilityCatalog = $null

if (Test-Path -LiteralPath $script:ModelCapabilityCatalogPath) {
    $script:ModelCapabilityCatalog = Get-Content -LiteralPath $script:ModelCapabilityCatalogPath -Raw | ConvertFrom-Json -Depth 20
}

$script:AllowedFrontmatterModels = if ($script:ModelCapabilityCatalog) {
    @(
        $script:ModelCapabilityCatalog.models |
            Where-Object { $_.clients.copilot_cli } |
            Select-Object -ExpandProperty id |
            Sort-Object -Unique
    )
}
else {
    @(
        "gpt-5.4-mini",
        "gpt-5.3-codex"
    )
}

$script:FrontmatterModelAliases = @{
    "gpt-5-4-mini" = "gpt-5.4-mini"
    "gpt-5-3-codex" = "gpt-5.3-codex"
    "claude-sonnet-4" = "claude-sonnet-4.6"
    "claude-sonnet-4-5" = "claude-sonnet-4.5"
}

$script:TierDefaultFrontmatterModels = @{
    "fast" = "gpt-5.4-mini"
    "balanced" = "gpt-5.3-codex"
    "reasoning" = "gpt-5.4"
}

function Get-AllowedFrontmatterModels {
    return @($script:AllowedFrontmatterModels)
}

function Get-ModelCapability {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Model
    )

    if (-not $script:ModelCapabilityCatalog) {
        return $null
    }

    return @($script:ModelCapabilityCatalog.models | Where-Object { $_.id -eq $Model } | Select-Object -First 1)[0]
}

function Test-ModelReasoningEffort {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Model,

        [AllowEmptyString()]
        [string]$ReasoningEffort = "",

        [string[]]$RuntimeSupportedReasoningEfforts = @()
    )

    if ([string]::IsNullOrWhiteSpace($ReasoningEffort)) {
        return $true
    }

    $capability = Get-ModelCapability -Model $Model
    if (-not $capability -or -not $capability.capabilities.configurable_reasoning) {
        return $false
    }

    return $ReasoningEffort -in $RuntimeSupportedReasoningEfforts
}

function Assert-ModelReasoningEffort {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Model,

        [AllowEmptyString()]
        [string]$ReasoningEffort = "",

        [string[]]$RuntimeSupportedReasoningEfforts = @()
    )

    if (-not (Test-ModelReasoningEffort -Model $Model -ReasoningEffort $ReasoningEffort -RuntimeSupportedReasoningEfforts $RuntimeSupportedReasoningEfforts)) {
        throw "Reasoning effort '$ReasoningEffort' is not supported for model '$Model'. Omit reasoning_effort or select a configurable-reasoning model."
    }
}

function Get-DefaultFrontmatterModel {
    return "gpt-5.4-mini"
}

function Get-TierDefaultFrontmatterModel {
    param([string]$Tier = "")

    $normalizedTier = $Tier.Trim().ToLowerInvariant()
    if ($script:TierDefaultFrontmatterModels.ContainsKey($normalizedTier)) {
        return $script:TierDefaultFrontmatterModels[$normalizedTier]
    }

    return Get-DefaultFrontmatterModel
}

function Resolve-FrontmatterModel {
    param(
        [string]$RequestedModel = "",
        [string]$Tier = "",
        [string]$Context = "frontmatter"
    )

    $raw = ($RequestedModel ?? "").Trim().Trim('"').Trim("'")
    $canonical = $raw.ToLowerInvariant()

    if ($script:FrontmatterModelAliases.ContainsKey($canonical)) {
        $canonical = $script:FrontmatterModelAliases[$canonical]
    }

    if ([string]::IsNullOrWhiteSpace($canonical)) {
        $fallback = Get-DefaultFrontmatterModel
        return [PSCustomObject]@{
            Model = $fallback
            Substituted = $true
            Reason = "missing model"
            Requested = $raw
        }
    }

    if ($script:AllowedFrontmatterModels -contains $canonical) {
        return [PSCustomObject]@{
            Model = $canonical
            Substituted = $false
            Reason = ""
            Requested = $raw
        }
    }

    $fallback = Get-TierDefaultFrontmatterModel -Tier $Tier
    return [PSCustomObject]@{
        Model = $fallback
        Substituted = $true
        Reason = "unsupported model"
        Requested = $raw
    }
}

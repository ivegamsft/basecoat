#!/usr/bin/env pwsh

$script:AllowedFrontmatterModels = @(
    "gpt-5.4-mini",
    "gpt-5.3-codex"
)

$script:FrontmatterModelAliases = @{
    "gpt-5-4-mini" = "gpt-5.4-mini"
    "gpt-5-3-codex" = "gpt-5.3-codex"
}

$script:TierDefaultFrontmatterModels = @{
    "fast" = "gpt-5.4-mini"
    "balanced" = "gpt-5.3-codex"
    "reasoning" = "gpt-5.3-codex"
}

function Get-AllowedFrontmatterModels {
    return @($script:AllowedFrontmatterModels)
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

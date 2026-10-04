$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'model-fallback-policy.ps1')

function Resolve-PreferredModelFamily {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequestedFamily
    )

    $raw = ($RequestedFamily ?? "").Trim().Trim('"').Trim("'")
    $canonical = $raw.ToLowerInvariant()

    if ($script:PreferredModelFamilyAliases.ContainsKey($canonical)) {
        $canonical = $script:PreferredModelFamilyAliases[$canonical]
    }

    if ($canonical -in $script:CanonicalPreferredModelFamilies) {
        return $canonical
    }

    $model = Resolve-FrontmatterModel -RequestedModel $canonical
    if (-not $model.Substituted) {
        return $model.Model
    }

    throw "Unknown preferred model family or runtime model ID '$raw'. Use a canonical family token or an ID from docs/reference/model-capabilities.json."
}

function Resolve-PreferredModelFamilies {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RequestedFamilies
    )

    $resolved = @(
        foreach ($family in $RequestedFamilies) {
            Resolve-PreferredModelFamily -RequestedFamily $family
        }
    )

    $duplicates = @($resolved | Group-Object | Where-Object Count -gt 1 | Select-Object -ExpandProperty Name)
    if ($duplicates.Count -gt 0) {
        throw "Preferred model families contain duplicate selectors after alias normalization: $($duplicates -join ', ')."
    }

    return $resolved
}

function Resolve-PreferredModelPolicy {
    param(
        [string]$PinnedModel = "",
        [string]$PinReason = "",
        [string]$Model = "",
        [string[]]$PreferredFamilies = @(),
        [string]$InheritedModel = "",
        [string[]]$InheritedPreferredFamilies = @(),
        [bool]$Fallback = $true,
        [string]$Tier = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($PinnedModel)) {
        if ([string]::IsNullOrWhiteSpace($PinReason)) {
            throw "A pinned_model requires a non-empty pin_reason."
        }

        $pin = Resolve-FrontmatterModel -RequestedModel $PinnedModel -Tier $Tier
        if ($pin.Substituted -or $pin.Model -cne $PinnedModel) {
            throw "Pinned model '$PinnedModel' must be an exact supported runtime model ID and is never substituted."
        }

        return [PSCustomObject]@{
            Source = "pinned_model"
            Model = $pin.Model
            PreferredFamilies = @()
            Fallback = $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        $selected = Resolve-FrontmatterModel -RequestedModel $Model -Tier $Tier
        return [PSCustomObject]@{
            Source = if ($selected.Substituted) { "model_fallback" } else { "model" }
            Model = $selected.Model
            PreferredFamilies = @()
            Fallback = $false
        }
    }

    $families = @($PreferredFamilies)
    $source = "model_policy"
    if ($families.Count -eq 0) {
        $families = @($InheritedPreferredFamilies)
        $source = "inherited_model_policy"
    }

    if ($families.Count -gt 0) {
        $normalizedFamilies = @(Resolve-PreferredModelFamilies -RequestedFamilies $families)
        if (-not $Fallback) {
            $normalizedFamilies = @($normalizedFamilies[0])
        }

        return [PSCustomObject]@{
            Source = $source
            Model = ""
            PreferredFamilies = $normalizedFamilies
            Fallback = $Fallback
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($InheritedModel)) {
        $inherited = Resolve-FrontmatterModel -RequestedModel $InheritedModel -Tier $Tier
        return [PSCustomObject]@{
            Source = "inherited_model"
            Model = $inherited.Model
            PreferredFamilies = @()
            Fallback = $inherited.Substituted
        }
    }

    return [PSCustomObject]@{
        Source = "tier_default"
        Model = Get-TierDefaultFrontmatterModel -Tier $Tier
        PreferredFamilies = @()
        Fallback = $true
    }
}

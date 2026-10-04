$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$policyScript = Join-Path $repoRoot 'scripts' 'model-policy-contract.ps1'
$validatorScript = Join-Path $repoRoot 'scripts' 'validate-model-policy.ps1'
$tempRoot = Join-Path $PSScriptRoot 'tmp-model-policy-tests'

. $policyScript

$aliases = @{
    sonnet = 'claude-sonnet'
    haiku  = 'claude-haiku'
    opus   = 'claude-opus'
}
foreach ($alias in $aliases.GetEnumerator()) {
    $actual = Resolve-PreferredModelFamily -RequestedFamily $alias.Key
    if ($actual -ne $alias.Value) {
        throw "Preferred family alias '$($alias.Key)' resolved to '$actual', expected '$($alias.Value)'."
    }
}

$exactModel = Resolve-PreferredModelFamily -RequestedFamily 'gpt-5.4-mini'
if ($exactModel -ne 'gpt-5.4-mini') {
    throw "Exact runtime model ID was not preserved: $exactModel"
}

$unknownAliasRejected = $false
try {
    Resolve-PreferredModelFamily -RequestedFamily 'sonett'
}
catch {
    $unknownAliasRejected = $true
}
if (-not $unknownAliasRejected) {
    throw 'Unknown model-family aliases must be rejected.'
}

$duplicateRejected = $false
try {
    Resolve-PreferredModelFamilies -RequestedFamilies @('sonnet', 'claude-sonnet')
}
catch {
    $duplicateRejected = $true
}
if (-not $duplicateRejected) {
    throw 'Selectors that collide after alias normalization must be rejected.'
}

$pinned = Resolve-PreferredModelPolicy `
    -PinnedModel 'claude-sonnet-5' `
    -PinReason 'Reproducibility test' `
    -Model 'gpt-5.4-mini' `
    -PreferredFamilies @('gpt')
if ($pinned.Source -ne 'pinned_model' -or $pinned.Model -ne 'claude-sonnet-5' -or $pinned.Fallback) {
    throw 'pinned_model must take precedence and must not receive fallback.'
}

$missingPinReasonRejected = $false
try {
    Resolve-PreferredModelPolicy -PinnedModel 'claude-sonnet-5'
}
catch {
    $missingPinReasonRejected = $true
}
if (-not $missingPinReasonRejected) {
    throw 'A pin without a reason must be rejected.'
}

$invalidPinRejected = $false
try {
    Resolve-PreferredModelPolicy -PinnedModel 'unknown-model' -PinReason 'Test'
}
catch {
    $invalidPinRejected = $true
}
if (-not $invalidPinRejected) {
    throw 'An unsupported pin must not silently fall back.'
}

$aliasedPinRejected = $false
try {
    Resolve-PreferredModelPolicy -PinnedModel 'claude-sonnet-4' -PinReason 'Test'
}
catch {
    $aliasedPinRejected = $true
}
if (-not $aliasedPinRejected) {
    throw 'A pinned model must be an exact runtime model ID, not a model alias.'
}

$legacy = Resolve-PreferredModelPolicy -Model 'gpt-5.4-mini' -PreferredFamilies @('claude-sonnet')
if ($legacy.Source -ne 'model' -or $legacy.Model -ne 'gpt-5.4-mini') {
    throw 'A local legacy model must remain authoritative over family preferences during migration.'
}

$localPreferences = Resolve-PreferredModelPolicy `
    -PreferredFamilies @('sonnet', 'gpt') `
    -InheritedPreferredFamilies @('haiku') `
    -Fallback $true
if ($localPreferences.Source -ne 'model_policy' -or
    ($localPreferences.PreferredFamilies -join ',') -ne 'claude-sonnet,gpt') {
    throw 'Local preferred families must override inherited preferences and preserve order after normalization.'
}

$firstOnly = Resolve-PreferredModelPolicy -PreferredFamilies @('sonnet', 'gpt') -Fallback $false
if (($firstOnly.PreferredFamilies -join ',') -ne 'claude-sonnet' -or $firstOnly.Fallback) {
    throw 'fallback: false must restrict family selection to the first normalized selector.'
}

$inherited = Resolve-PreferredModelPolicy -InheritedPreferredFamilies @('haiku', 'gpt')
if ($inherited.Source -ne 'inherited_model_policy' -or
    ($inherited.PreferredFamilies -join ',') -ne 'claude-haiku,gpt') {
    throw 'Explicit inherited family selectors must be used only when local selectors are absent.'
}

$inheritedModel = Resolve-PreferredModelPolicy -InheritedModel 'gpt-5.4'
if ($inheritedModel.Source -ne 'inherited_model' -or $inheritedModel.Model -ne 'gpt-5.4') {
    throw 'An explicitly supplied inherited model must be retained when local selectors are absent.'
}

$default = Resolve-PreferredModelPolicy -Tier 'fast'
if ($default.Source -ne 'tier_default' -or $default.Model -ne 'gpt-5.4-mini') {
    throw 'An absent local and inherited selection must use the requested tier default.'
}

if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'agents') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'skills') -Force | Out-Null

try {
    $validAsset = Join-Path $tempRoot 'agents' 'valid.agent.md'
    Set-Content -LiteralPath $validAsset -Value @'
---
name: valid-agent
model_policy:
  fallback: true
  preferred_families: [claude-sonnet, gpt-5.4-mini]
---
Body
'@

    & pwsh -NoProfile -File $validatorScript -RootDir $tempRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'The model policy validator rejected canonical family and exact-model selectors.'
    }

    Set-Content -LiteralPath $validAsset -Value @'
---
name: invalid-agent
model_policy:
  fallback: true
  preferred_families: [sonett]
---
Body
'@
    & pwsh -NoProfile -File $validatorScript -RootDir $tempRoot 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        throw 'The model policy validator must reject unknown family aliases.'
    }

    Set-Content -LiteralPath $validAsset -Value @'
---
name: invalid-pin
pinned_model: claude-sonnet-5
---
Body
'@
    & pwsh -NoProfile -File $validatorScript -RootDir $tempRoot 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        throw 'The model policy validator must reject a pin without pin_reason.'
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

& pwsh -NoProfile -File $validatorScript -RootDir $repoRoot
if ($LASTEXITCODE -ne 0) {
    throw 'The repository model policy selectors do not satisfy the canonical contract.'
}

Write-Host 'Model policy contract tests passed.' -ForegroundColor Green

#!/usr/bin/env pwsh
param(
    [string]$AgentsPath = (Join-Path $PSScriptRoot ".." "agents"),
    [string]$ModelMapPath = (Join-Path $PSScriptRoot ".." "docs" "reference" "model-map.json"),
    [string]$ModelInventoryPath = (Join-Path $PSScriptRoot ".." "docs" "reference" "model-inventory.md")
)

$ErrorActionPreference = "Stop"

$policyScriptPath = Join-Path $PSScriptRoot "model-fallback-policy.ps1"
if (-not (Test-Path $policyScriptPath)) {
    throw "Model fallback policy script not found: $policyScriptPath"
}
. $policyScriptPath

$modelBuckets = @{}
$agentFiles = Get-ChildItem -Path $AgentsPath -Filter "*.agent.md" -File | Sort-Object Name

foreach ($agentFile in $agentFiles) {
    $content = Get-Content -Path $agentFile.FullName -Raw
    $rawModel = if ($content -match '(?m)^model:\s*(.+)$') { $Matches[1].Trim().Trim('"').Trim("'") } else { "" }
    $canonicalModel = Resolve-ModelWithFallback -ModelId $rawModel -Context "generate-model-inventory:$($agentFile.Name)"
    if ([string]::IsNullOrWhiteSpace($canonicalModel)) { continue }
    $aliasValue = if (Test-IsAllowedModel -ModelId $rawModel) { $rawModel } else { $canonicalModel }

    if (-not $modelBuckets.ContainsKey($canonicalModel)) {
        $modelBuckets[$canonicalModel] = [ordered]@{
            canonical = $canonicalModel
            count = 0
            aliases = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        }
    }

    $bucket = $modelBuckets[$canonicalModel]
    $bucket.count++
    [void]$bucket.aliases.Add($aliasValue)
}

$models = @(
    foreach ($canonical in ($modelBuckets.Keys | Sort-Object)) {
        $bucket = $modelBuckets[$canonical]
        [ordered]@{
            canonical = $bucket.canonical
            count = $bucket.count
            aliases = @($bucket.aliases | Sort-Object)
        }
    }
)

$modelMap = [ordered]@{
    generated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    source = "agents/*.agent.md"
    models = $models
}

$modelMapDir = Split-Path -Parent $ModelMapPath
if (-not (Test-Path $modelMapDir)) {
    New-Item -ItemType Directory -Path $modelMapDir -Force | Out-Null
}
$modelMap | ConvertTo-Json -Depth 6 | Set-Content -Path $ModelMapPath -Encoding UTF8

$lines = @(
    "# Model Inventory"
    ""
    "Generated from agent frontmatter models using the shared fallback policy."
    ""
    "| Canonical key | Aliases observed | Count |"
    "|---|---|---|"
)

foreach ($model in $models) {
    $aliasText = ($model.aliases -join ", ")
    $lines += "| ``$($model.canonical)`` | $aliasText | $($model.count) |"
}

$inventoryDir = Split-Path -Parent $ModelInventoryPath
if (-not (Test-Path $inventoryDir)) {
    New-Item -ItemType Directory -Path $inventoryDir -Force | Out-Null
}
$lines | Set-Content -Path $ModelInventoryPath -Encoding UTF8

Write-Host "Model map written: $ModelMapPath"
Write-Host "Model inventory written: $ModelInventoryPath"
Write-Host "Canonical models: $($models.Count)"

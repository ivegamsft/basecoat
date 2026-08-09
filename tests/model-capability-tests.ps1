$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$syncScript = Join-Path $repoRoot 'scripts' 'sync-model-capabilities.ps1'
$policyScript = Join-Path $repoRoot 'scripts' 'model-fallback-policy.ps1'
$catalogPath = Join-Path $repoRoot 'docs' 'reference' 'model-capabilities.json'
$capabilityDocPath = Join-Path $repoRoot 'docs' 'reference' 'model-capabilities.md'
$auditPath = Join-Path $repoRoot 'docs' 'reference' 'model-assignment-audit.md'
$workflowPath = Join-Path $repoRoot '.github' 'workflows' 'model-capability-refresh.yml'
$tempRoot = Join-Path $PSScriptRoot 'tmp-model-capability-tests'

if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $tempCatalog = Join-Path $tempRoot 'model-capabilities.json'
    $tempDoc = Join-Path $tempRoot 'model-capabilities.md'
    $tempAudit = Join-Path $tempRoot 'model-assignment-audit.md'
    Copy-Item -LiteralPath $catalogPath -Destination $tempCatalog

    & pwsh -NoProfile -File $syncScript `
        -CatalogPath $tempCatalog `
        -AgentsPath (Join-Path $repoRoot 'agents') `
        -DocumentationPath $tempDoc `
        -AssignmentAuditPath $tempAudit
    if ($LASTEXITCODE -ne 0) {
        throw 'sync-model-capabilities.ps1 exited with non-zero status'
    }

    foreach ($pair in @(
        @($catalogPath, $tempCatalog),
        @($capabilityDocPath, $tempDoc),
        @($auditPath, $tempAudit)
    )) {
        $expected = (Get-Content -LiteralPath $pair[0] -Raw) -replace "`r`n", "`n"
        $actual = (Get-Content -LiteralPath $pair[1] -Raw) -replace "`r`n", "`n"
        if ($actual -cne $expected) {
            throw "Generated model artifact is stale: $($pair[0])"
        }
    }

    $catalogRaw = Get-Content -LiteralPath $catalogPath -Raw
    $catalog = $catalogRaw | ConvertFrom-Json -Depth 20
    if ($catalog.models.Count -lt 20) {
        throw "Expected a complete public model baseline, found only $($catalog.models.Count) models"
    }
    if ($catalogRaw -notmatch '"clients"\s*:' -or $catalogRaw -notmatch '"auto_selection"\s*:') {
        throw 'Client availability and Auto-selection metadata must both be represented'
    }
    if ($catalogRaw -notmatch '"model_supported_clients"\s*:') {
        throw 'Catalog provenance must include the GitHub client-support table'
    }
    if ($catalogRaw -notmatch '"supported_reasoning_efforts"\s*:\s*\[\s*\]') {
        throw 'Fixed-effort models must serialize an empty reasoning-effort array'
    }

    $haiku = @($catalog.models | Where-Object { $_.id -eq 'claude-haiku-4.5' })[0]
    if (-not $haiku -or $haiku.capabilities.configurable_reasoning) {
        throw 'Claude Haiku 4.5 must be recorded as fixed-effort'
    }

    $codex = @($catalog.models | Where-Object { $_.id -eq 'gpt-5.3-codex' })[0]
    if (-not $codex -or -not $codex.capabilities.configurable_reasoning) {
        throw 'GPT-5.3-Codex must be recorded as configurable-reasoning'
    }
    if ($null -ne $codex.capabilities.supported_reasoning_efforts) {
        throw 'Public model data must not invent per-model reasoning-effort values'
    }
    if ('gemini-3.1-pro-preview' -notin @($catalog.models.id)) {
        throw 'Gemini 3.1 Pro must use the Copilot CLI runtime model ID'
    }
    if ('mai-code-1-flash-picker' -notin @($catalog.models.id)) {
        throw 'MAI-Code-1-Flash must use the Copilot CLI runtime model ID'
    }

    $audit = Get-Content -LiteralPath $auditPath -Raw
    if ($audit -match '\| unknown-model \|') {
        throw 'Agent model assignments contain unknown model IDs'
    }

    . $policyScript
    $manualCliModel = Resolve-FrontmatterModel -RequestedModel 'claude-opus-5'
    if ($manualCliModel.Substituted -or $manualCliModel.Model -ne 'claude-opus-5') {
        throw 'CLI-supported manual models must not be filtered out by Auto-selection eligibility'
    }
    $unsupportedCliModel = Resolve-FrontmatterModel -RequestedModel 'gpt-5.4-nano'
    if (-not $unsupportedCliModel.Substituted) {
        throw 'Models not supported by the Copilot CLI client must fail closed'
    }
    if (Test-ModelReasoningEffort -Model 'claude-haiku-4.5' -ReasoningEffort 'medium') {
        throw 'Claude Haiku 4.5 must reject medium reasoning effort'
    }
    if (-not (Test-ModelReasoningEffort -Model 'gpt-5.3-codex' -ReasoningEffort 'medium' -RuntimeSupportedReasoningEfforts @('low', 'medium', 'high'))) {
        throw 'GPT-5.3-Codex must accept medium reasoning effort'
    }
    if (-not (Test-ModelReasoningEffort -Model 'claude-haiku-4.5' -ReasoningEffort '')) {
        throw 'An omitted reasoning effort must remain valid for fixed-effort models'
    }
    if (Test-ModelReasoningEffort -Model 'claude-haiku-4.5' -ReasoningEffort 'none') {
        throw "Explicit reasoning effort 'none' must not be treated as omission"
    }

    $rejected = $false
    try {
        Assert-ModelReasoningEffort -Model 'claude-haiku-4.5' -ReasoningEffort 'medium'
    }
    catch {
        $rejected = $_.Exception.Message -match "not supported for model 'claude-haiku-4.5'"
    }
    if (-not $rejected) {
        throw 'Reasoning-effort assertion did not fail closed for Claude Haiku 4.5'
    }

    $workflow = Get-Content -LiteralPath $workflowPath -Raw
    if ($workflow -notmatch 'GH_TOKEN:\s*\$\{\{\s*github\.token\s*\}\}') {
        throw 'Model refresh workflow must authenticate gh api with github.token'
    }

    $malformedCatalog = Join-Path $tempRoot 'malformed.json'
    '{"schema_version":1,"models":[]}' | Set-Content -LiteralPath $malformedCatalog -Encoding UTF8
    $malformedOutput = & pwsh -NoProfile -File $syncScript `
        -CatalogPath $malformedCatalog `
        -DocumentationPath (Join-Path $tempRoot 'malformed.md') `
        -AssignmentAuditPath (Join-Path $tempRoot 'malformed-audit.md') 2>&1
    if ($LASTEXITCODE -eq 0 -or ($malformedOutput -join "`n") -notmatch 'contains no models') {
        throw 'Malformed model catalogs must fail closed'
    }

    Write-Host 'Model capability tests passed'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

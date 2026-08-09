#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$CatalogPath = 'docs/reference/model-capabilities.json',
    [string]$DocumentationPath = 'docs/reference/model-capabilities.md',
    [string]$AssignmentAuditPath = 'docs/reference/model-assignment-audit.md',
    [string]$AgentsPath = 'agents',
    [string]$SkillsPath = 'skills',
    [switch]$Refresh
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return Join-Path $repoRoot $Path
}

function Get-GitHubDocsFile {
    param([string]$Path)

    $response = gh api "repos/github/docs/contents/$Path" | ConvertFrom-Json
    if (-not $response.content -or -not $response.sha) {
        throw "GitHub Docs API returned malformed content for $Path"
    }

    return [PSCustomObject]@{
        Path = $Path
        Sha = $response.sha
        Content = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($response.content -replace '\s', '')))
    }
}

function ConvertFrom-SimpleModelYaml {
    param([string]$Content)

    $items = [System.Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in $Content -split '\r?\n') {
        if ($line -match "^- name:\s*['""]?(?<value>.*?)['""]?\s*$") {
            if ($current) {
                $items.Add([PSCustomObject]$current)
            }
            $current = [ordered]@{ name = $Matches.value }
            continue
        }

        if ($current -and $line -match "^\s{2}(?<key>[a-z_]+):\s*['""]?(?<value>.*?)['""]?\s*$") {
            $value = $Matches.value
            if ($value -in @('true', 'false')) {
                $value = [bool]::Parse($value)
            }
            $current[$Matches.key] = $value
        }
    }

    if ($current) {
        $items.Add([PSCustomObject]$current)
    }
    return @($items)
}

function ConvertTo-ModelId {
    param([string]$Name)

    $runtimeIdOverrides = @{
        'Gemini 3.1 Pro' = 'gemini-3.1-pro-preview'
        'MAI-Code-1-Flash' = 'mai-code-1-flash-picker'
    }
    if ($runtimeIdOverrides.ContainsKey($Name)) {
        return $runtimeIdOverrides[$Name]
    }

    $id = $Name.ToLowerInvariant()
    $id = $id -replace '\s+\(fast mode\)\s+\(preview\)$', '-fast'
    $id = $id -replace '[^a-z0-9.]+', '-'
    return $id.Trim('-')
}

function Get-VariableMap {
    param([string]$Content)

    $map = @{}
    foreach ($line in $Content -split '\r?\n') {
        if ($line -match "^(?<key>copilot_[a-z0-9_]+):\s*['""](?<value>.*?)['""]\s*$") {
            $map[$Matches.key] = $Matches.value
        }
    }
    return $map
}

function Get-ExtendedCapabilities {
    param(
        [string]$Content,
        [hashtable]$VariableMap
    )

    $capabilities = @{}
    foreach ($line in $Content -split '\r?\n') {
        if ($line -notmatch '^\| \{% data variables\.copilot\.(?<key>[a-z0-9_]+) %\} \| \{% octicon "[^"]+" aria-label="(?<context>[^"]+)" %\} \| \{% octicon "[^"]+" aria-label="(?<reasoning>[^"]+)" %\} \|') {
            continue
        }
        if (-not $VariableMap.ContainsKey($Matches.key)) {
            throw "Missing Copilot variable mapping for $($Matches.key)"
        }
        $capabilities[$VariableMap[$Matches.key]] = [ordered]@{
            million_token_context = $Matches.context -eq 'Supported'
            configurable_reasoning = $Matches.reasoning -eq 'Supported'
        }
    }
    return $capabilities
}

function Get-FrontmatterValue {
    param(
        [string]$Content,
        [string]$Field
    )

    if ($Content -match "(?m)^$([regex]::Escape($Field)):\s*(?<value>.+?)\s*$") {
        return $Matches.value.Trim().Trim('"').Trim("'")
    }
    return ''
}

function Get-AssignmentRows {
    param([object[]]$CatalogModels)

    $catalogById = @{}
    foreach ($model in $CatalogModels) {
        $catalogById[$model.id] = $model
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    $assets = @()
    $assets += Get-ChildItem -Path $AgentsPath -Filter '*.agent.md' -File
    $assets += Get-ChildItem -Path $SkillsPath -Recurse -Filter 'SKILL.md' -File
    foreach ($asset in ($assets | Sort-Object FullName)) {
        $content = Get-Content -Path $asset.FullName -Raw
        $name = Get-FrontmatterValue -Content $content -Field 'name'
        $assignments = [System.Collections.Generic.List[object]]::new()
        foreach ($field in @('model', 'pinned_model')) {
            $value = Get-FrontmatterValue -Content $content -Field $field
            if ($value) {
                $assignments.Add([PSCustomObject]@{ Field = $field; Model = $value })
            }
        }
        $fallbackValue = Get-FrontmatterValue -Content $content -Field 'fallback_models'
        if ($fallbackValue) {
            foreach ($fallbackModel in (($fallbackValue.Trim('[', ']') -split ',') | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ })) {
                $assignments.Add([PSCustomObject]@{ Field = 'fallback_models'; Model = $fallbackModel })
            }
        }

        foreach ($assignment in $assignments) {
            $model = $assignment.Model.ToLowerInvariant()
            $status = 'public-supported'
            $recommendation = 'Keep assignment; verify runtime entitlement and task-specific evals.'
            if (-not $catalogById.ContainsKey($model)) {
                $status = 'unknown-model'
                $recommendation = 'Replace with a GitHub-supported model or document a BYOK provider.'
            }
            elseif (-not $catalogById[$model].clients.copilot_cli) {
                $status = 'not-cli-supported'
                $recommendation = 'Replace with a model supported by the Copilot CLI client.'
            }
            elseif (-not $catalogById[$model].capabilities.configurable_reasoning) {
                $status = 'fixed-effort'
                $recommendation = 'Keep only when the invocation omits reasoning_effort; never map reasoning_depth to a provider effort.'
            }

            $rows.Add([PSCustomObject]@{
                asset = $asset.FullName.Substring($repoRoot.Path.Length + 1).Replace('\', '/')
                name = $name
                field = $assignment.Field
                model = $model
                status = $status
                recommendation = $recommendation
            })
        }
    }
    return @($rows)
}

function Write-CatalogDocumentation {
    param(
        [object]$Catalog,
        [object[]]$Assignments
    )

    $resolvedDocumentationPath = Resolve-RepoPath -Path $DocumentationPath
    $resolvedAssignmentAuditPath = Resolve-RepoPath -Path $AssignmentAuditPath
    foreach ($outputPath in @($resolvedDocumentationPath, $resolvedAssignmentAuditPath)) {
        $outputDirectory = Split-Path -Parent $outputPath
        if (-not (Test-Path -LiteralPath $outputDirectory)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Model Capability Framework')
    $lines.Add('')
    $lines.Add('Generated from GitHub Docs model data retrieved through `gh api`, then enriched with BaseCoat routing guidance. Effective user and organization entitlements must still be verified by the authenticated Copilot runtime.')
    $lines.Add('')
    $lines.Add('## Selection contract')
    $lines.Add('')
    $lines.Add('1. Filter to GitHub-supported models and the target client.')
    $lines.Add('2. Intersect with effective organization and user policy when runtime data is available.')
    $lines.Add('3. Match task capability requirements before cost or latency.')
    $lines.Add('4. Emit `reasoning_effort` only when the model is configurable and the authenticated runtime reports the exact effort value.')
    $lines.Add('5. Prefer the lowest-cost model that passes task-specific evaluations.')
    $lines.Add('')
    $lines.Add('`reasoning_depth` describes task complexity. It is not a provider parameter and must never be copied automatically into `reasoning_effort`.')
    $lines.Add('')
    $lines.Add('## Models')
    $lines.Add('')
    $lines.Add('| Model | Provider | Status | Copilot CLI | CLI auto-selection | Configurable reasoning | Task area |')
    $lines.Add('|---|---|---|---:|---:|---:|---|')
    foreach ($model in $Catalog.models) {
        $lines.Add("| ``$($model.id)`` | $($model.provider) | $($model.release_status) | $($model.clients.copilot_cli) | $($model.auto_selection.copilot_cli) | $($model.capabilities.configurable_reasoning) | $($model.task_area) |")
    }
    $lines.Add('')
    $lines.Add('## Runtime availability')
    $lines.Add('')
    $lines.Add('GitHub public REST does not currently expose the effective per-user Copilot model allowlist. The refresh script therefore records the public supported baseline from `github/docs`; callers must intersect it with the access-filtered Copilot runtime catalog when available. Do not substitute the GitHub Models inference catalog.')

    [IO.File]::WriteAllText(
        $resolvedDocumentationPath,
        ($lines -join "`n") + "`n",
        [Text.UTF8Encoding]::new($false)
    )

    $audit = [System.Collections.Generic.List[string]]::new()
    $audit.Add('# Model Assignment Audit')
    $audit.Add('')
    $audit.Add("Assignments scanned: $($Assignments.Count).")
    $audit.Add('')
    $audit.Add('| Asset | Field | Model | Status | Recommendation |')
    $audit.Add('|---|---|---|---|---|')
    foreach ($assignment in $Assignments) {
        $audit.Add("| [$($assignment.asset)](https://github.com/IBuySpy-Shared/basecoat/blob/main/$($assignment.asset)) | ``$($assignment.field)`` | ``$($assignment.model)`` | $($assignment.status) | $($assignment.recommendation) |")
    }
    [IO.File]::WriteAllText(
        $resolvedAssignmentAuditPath,
        ($audit -join "`n") + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

$resolvedCatalogPath = Resolve-RepoPath -Path $CatalogPath
if ($Refresh) {
    foreach ($command in @('gh')) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "$command is required to refresh model capabilities"
        }
    }

    $releaseFile = Get-GitHubDocsFile -Path 'data/tables/copilot/model-release-status.yml'
    $comparisonFile = Get-GitHubDocsFile -Path 'data/tables/copilot/model-comparison.yml'
    $autoFile = Get-GitHubDocsFile -Path 'data/tables/copilot/auto-model-selection.yml'
    $clientsFile = Get-GitHubDocsFile -Path 'data/tables/copilot/model-supported-clients.yml'
    $supportedFile = Get-GitHubDocsFile -Path 'content/copilot/reference/ai-models/supported-models.md'
    $variablesFile = Get-GitHubDocsFile -Path 'data/variables/copilot.yml'

    $releaseModels = @(ConvertFrom-SimpleModelYaml -Content $releaseFile.Content)
    if ($releaseModels.Count -lt 1) {
        throw 'GitHub Docs model release table contained no parseable models'
    }
    $comparisonByName = @{}
    foreach ($model in (ConvertFrom-SimpleModelYaml -Content $comparisonFile.Content)) {
        $comparisonByName[$model.name] = $model
    }
    if ($comparisonByName.Count -lt 1) {
        throw 'GitHub Docs model comparison table contained no parseable models'
    }
    $autoByName = @{}
    foreach ($model in (ConvertFrom-SimpleModelYaml -Content $autoFile.Content)) {
        $autoByName[$model.name] = $model
    }
    if ($autoByName.Count -lt 1) {
        throw 'GitHub Docs Auto-selection table contained no parseable models'
    }
    $clientsByName = @{}
    foreach ($model in (ConvertFrom-SimpleModelYaml -Content $clientsFile.Content)) {
        $clientsByName[$model.name] = $model
    }
    if ($clientsByName.Count -lt 1) {
        throw 'GitHub Docs model client-support table contained no parseable models'
    }
    $variableMap = Get-VariableMap -Content $variablesFile.Content
    if ($variableMap.Count -lt 1) {
        throw 'GitHub Docs Copilot variable table contained no parseable values'
    }
    $extended = Get-ExtendedCapabilities -Content $supportedFile.Content -VariableMap $variableMap
    if ($extended.Count -lt 1) {
        throw 'GitHub Docs supported-models page contained no parseable capabilities'
    }

    $models = foreach ($model in $releaseModels) {
        $comparison = $comparisonByName[$model.name]
        $auto = $autoByName[$model.name]
        $clients = $clientsByName[$model.name]
        $capability = $extended[$model.name]
        $configurableReasoning = [bool]($capability -and $capability.configurable_reasoning)
        [object[]]$reasoningEfforts = @()
        [ordered]@{
            id = ConvertTo-ModelId -Name $model.name
            name = $model.name
            provider = $model.provider
            release_status = $model.release_status
            task_area = if ($comparison) { $comparison.task_area } else { 'Not classified by GitHub Docs' }
            excels_at = if ($comparison) { $comparison.excels_at } else { 'Not classified by GitHub Docs' }
            auto_selection = [ordered]@{
                copilot_cli = [bool]($auto -and $auto.cli)
                copilot_chat = [bool]($auto -and $auto.chat)
                cloud_agent = [bool]($auto -and $auto.cloud_agent)
                copilot_app = [bool]($auto -and $auto.app)
            }
            clients = [ordered]@{
                copilot_cli = [bool]($clients -and $clients.cli)
                github_dotcom = [bool]($clients -and $clients.dotcom)
                vscode = [bool]($clients -and $clients.vscode)
                visual_studio = [bool]($clients -and $clients.vs)
                eclipse = [bool]($clients -and $clients.eclipse)
                xcode = [bool]($clients -and $clients.xcode)
                jetbrains = [bool]($clients -and $clients.jetbrains)
            }
            capabilities = [ordered]@{
                million_token_context = [bool]($capability -and $capability.million_token_context)
                configurable_reasoning = $configurableReasoning
                supported_reasoning_efforts = if ($configurableReasoning) { $null } else { ,$reasoningEfforts }
            }
        }
        $duplicateModelIds = @($models | Group-Object id | Where-Object Count -gt 1)
        if ($duplicateModelIds.Count -gt 0) {
            throw "Canonical model IDs are not unique: $(($duplicateModelIds.Name | Sort-Object) -join ', ')"
        }
    }

    $catalog = [ordered]@{
        schema_version = 1
        source = [ordered]@{
            repository = 'github/docs'
            files = [ordered]@{
                model_release_status = $releaseFile.Sha
                model_comparison = $comparisonFile.Sha
                auto_model_selection = $autoFile.Sha
                model_supported_clients = $clientsFile.Sha
                supported_models = $supportedFile.Sha
                copilot_variables = $variablesFile.Sha
            }
        }
        models = @($models | Sort-Object provider, name)
    }

    $catalogDirectory = Split-Path -Parent $resolvedCatalogPath
    if (-not (Test-Path $catalogDirectory)) {
        New-Item -ItemType Directory -Path $catalogDirectory -Force | Out-Null
    }
    [IO.File]::WriteAllText(
        $resolvedCatalogPath,
        ($catalog | ConvertTo-Json -Depth 10) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

if (-not (Test-Path $resolvedCatalogPath)) {
    throw "Model capability catalog not found: $resolvedCatalogPath. Run with -Refresh."
}

$catalog = Get-Content -Path $resolvedCatalogPath -Raw | ConvertFrom-Json
if (-not $catalog.models -or $catalog.models.Count -lt 1) {
    throw 'Model capability catalog contains no models'
}
$assignments = Get-AssignmentRows -CatalogModels $catalog.models
Write-CatalogDocumentation -Catalog $catalog -Assignments $assignments
Write-Host "Model capability catalog: $($catalog.models.Count) models"
Write-Host "Model assignments audited: $($assignments.Count)"

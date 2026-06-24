[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ManifestPath,
    [ValidateSet('validate', 'dry-run', 'apply')]
    [string]$Mode = 'dry-run',
    [string]$Owner,
    [int]$ProjectNumber,
    [string]$CurrentStatePath,
    [string]$JsonReportPath = 'artifacts\aidl-portfolio-project-bootstrap\bootstrap-report.json',
    [string]$MarkdownReportPath = 'artifacts\aidl-portfolio-project-bootstrap\bootstrap-report.md',
    [switch]$FailOnDrift
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Ensure-ParentDirectory {
    param([string]$PathValue)
    $parent = Split-Path -Path $PathValue -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Read-JsonFile {
    param([string]$PathValue)
    if (-not (Test-Path $PathValue)) {
        throw "File not found: $PathValue"
    }
    return Get-Content -Path $PathValue -Raw | ConvertFrom-Json -Depth 100
}

function New-ResultSummary {
    return [ordered]@{
        plannedCreates = 0
        appliedCreates = 0
        skippedNoOp = 0
        mismatches = 0
        unknownChecks = 0
    }
}

function Normalize-FieldType {
    param([string]$Value)
    $normalized = ($Value ?? '').Trim().ToLowerInvariant()
    switch ($normalized) {
        'single_select' { return 'single_select' }
        'singleselect' { return 'single_select' }
        'single-select' { return 'single_select' }
        'text' { return 'text' }
        'number' { return 'number' }
        'date' { return 'date' }
        'iteration' { return 'iteration' }
        default { return $normalized }
    }
}

function Get-OptionNames {
    param($Field)
    $options = @()
    if ($null -eq $Field) { return @() }
    if ($Field.PSObject.Properties.Name -contains 'options') {
        foreach ($option in @($Field.options)) {
            if ($option -is [string]) {
                $options += $option.Trim()
            } elseif ($option -and $option.PSObject.Properties.Name -contains 'name') {
                $options += "$($option.name)".Trim()
            }
        }
    }
    return @($options | Where-Object { $_ -ne '' })
}

function Get-MapByName {
    param($Items)
    $map = @{}
    foreach ($item in @($Items)) {
        if (-not $item) { continue }
        $name = "$($item.name)".Trim()
        if (-not $name) { continue }
        $map[$name.ToLowerInvariant()] = $item
    }
    return $map
}

function Normalize-StringArray {
    param($Value)
    return @($Value | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne '' } | Sort-Object -Unique)
}

function Validate-Manifest {
    param($ManifestObject)

    $errors = @()
    if (-not $ManifestObject.schemaVersion) {
        $errors += 'Manifest is missing required property: schemaVersion'
    }
    if (-not ($ManifestObject.PSObject.Properties.Name -contains 'fields')) {
        $errors += 'Manifest is missing required property: fields'
    }
    if (-not ($ManifestObject.PSObject.Properties.Name -contains 'views')) {
        $errors += 'Manifest is missing required property: views'
    }
    if (-not ($ManifestObject.PSObject.Properties.Name -contains 'rules')) {
        $errors += 'Manifest is missing required property: rules'
    }

    foreach ($field in @($ManifestObject.fields)) {
        $fieldName = "$($field.name)".Trim()
        $fieldType = Normalize-FieldType -Value "$($field.type)"
        if (-not $fieldName) {
            $errors += 'Manifest field entry missing name'
            continue
        }
        if ($fieldType -notin @('single_select', 'text', 'number', 'date', 'iteration')) {
            $errors += "Manifest field '$fieldName' has unsupported type '$($field.type)'"
        }
        if ($fieldType -eq 'single_select') {
            $options = Get-OptionNames -Field $field
            if (@($options).Count -eq 0) {
                $errors += "Manifest field '$fieldName' requires non-empty options for single_select type"
            }
        }
    }

    foreach ($view in @($ManifestObject.views)) {
        if (-not "$($view.name)".Trim()) {
            $errors += 'Manifest view entry missing name'
        }
    }

    foreach ($rule in @($ManifestObject.rules)) {
        if (-not "$($rule.id)".Trim()) {
            $errors += 'Manifest rule entry missing id'
        }
        if (-not "$($rule.name)".Trim()) {
            $errors += "Manifest rule '$($rule.id)' is missing name"
        }
    }

    return @($errors)
}

function Get-LiveProjectFields {
    param(
        [string]$ProjectOwner,
        [int]$ProjectId
    )

    $raw = & gh project field-list $ProjectId --owner $ProjectOwner --format json
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fetch project fields for owner '$ProjectOwner' project '$ProjectId'"
    }

    $liveFields = @()
    foreach ($field in @($raw | ConvertFrom-Json -Depth 100)) {
        $liveFields += [pscustomobject]@{
            name = "$($field.name)".Trim()
            type = Normalize-FieldType -Value "$($field.dataType)"
            options = @($field.options)
        }
    }
    return @($liveFields)
}

function Add-Finding {
    param(
        [System.Collections.ArrayList]$FindingList,
        [string]$Id,
        [string]$Severity,
        [string]$Category,
        [string]$Message
    )
    [void]$FindingList.Add([pscustomobject]@{
            id = $Id
            severity = $Severity
            category = $Category
            message = $Message
        })
}

function Add-Action {
    param(
        [System.Collections.ArrayList]$ActionList,
        [string]$Type,
        [string]$Name,
        $Payload
    )
    [void]$ActionList.Add([pscustomobject]@{
            type = $Type
            name = $Name
            payload = $Payload
            status = 'planned'
        })
}

$manifestFullPath = Resolve-Path $ManifestPath
$manifest = Read-JsonFile -PathValue $manifestFullPath

$schemaPath = Join-Path $repoRoot 'docs\specs\aidl-portfolio\project-bootstrap-manifest.schema.json'
if (Test-Path $schemaPath) {
    try {
        $null = Test-Json -Json (Get-Content -Path $manifestFullPath -Raw) -SchemaFile $schemaPath -ErrorAction Stop
    } catch {
        throw "Manifest does not match schema at '$schemaPath': $($_.Exception.Message)"
    }
}

$manifestErrors = @(Validate-Manifest -ManifestObject $manifest)
if (@($manifestErrors).Count -gt 0) {
    throw ("Manifest validation failed:`n- " + ($manifestErrors -join "`n- "))
}

$currentState = [ordered]@{
    fields = @()
    views  = @()
    rules  = @()
}

$usingLiveProject = $false
if ($Owner -and $ProjectNumber -gt 0) {
    $usingLiveProject = $true
    $currentState.fields = Get-LiveProjectFields -ProjectOwner $Owner -ProjectId $ProjectNumber
}

if ($CurrentStatePath) {
    $currentStateDoc = Read-JsonFile -PathValue (Resolve-Path $CurrentStatePath)
    if ($currentStateDoc.PSObject.Properties.Name -contains 'fields') {
        if (-not $usingLiveProject) {
            $currentState.fields = @($currentStateDoc.fields)
        }
    }
    if ($currentStateDoc.PSObject.Properties.Name -contains 'views') {
        $currentState.views = @($currentStateDoc.views)
    }
    if ($currentStateDoc.PSObject.Properties.Name -contains 'rules') {
        $currentState.rules = @($currentStateDoc.rules)
    }
}

if (-not $usingLiveProject -and -not $CurrentStatePath) {
    throw "$Mode requires either -Owner/-ProjectNumber (live field bootstrap) or -CurrentStatePath (offline snapshot mode)."
}

$summary = New-ResultSummary
$actions = [System.Collections.ArrayList]::new()
$findings = [System.Collections.ArrayList]::new()

$currentFieldMap = Get-MapByName -Items $currentState.fields
$currentViewMap = Get-MapByName -Items $currentState.views
$currentRuleMap = @{}
foreach ($rule in @($currentState.rules)) {
    $ruleId = "$($rule.id)".Trim().ToLowerInvariant()
    if ($ruleId) {
        $currentRuleMap[$ruleId] = $rule
    }
}

foreach ($manifestField in @($manifest.fields)) {
    $fieldName = "$($manifestField.name)".Trim()
    $fieldType = Normalize-FieldType -Value "$($manifestField.type)"
    $fieldKey = $fieldName.ToLowerInvariant()

    if (-not $currentFieldMap.ContainsKey($fieldKey)) {
        Add-Action -ActionList $actions -Type 'create_field' -Name $fieldName -Payload $manifestField
        $summary.plannedCreates++
        continue
    }

    $currentField = $currentFieldMap[$fieldKey]
    $currentType = Normalize-FieldType -Value "$($currentField.type)"
    if ($currentType -ne $fieldType) {
        Add-Finding -FindingList $findings -Id 'FIELD_TYPE_MISMATCH' -Severity 'high' -Category 'fields' -Message "Field '$fieldName' type mismatch. Expected '$fieldType', found '$currentType'."
        $summary.mismatches++
    }

    if ($fieldType -eq 'single_select') {
        $expectedOptions = Get-OptionNames -Field $manifestField
        $actualOptions = Get-OptionNames -Field $currentField
        $missingOptions = @($expectedOptions | Where-Object { $_ -notin $actualOptions })
        if (@($missingOptions).Count -gt 0) {
            Add-Finding -FindingList $findings -Id 'FIELD_OPTIONS_MISMATCH' -Severity 'medium' -Category 'fields' -Message "Field '$fieldName' is missing options: $($missingOptions -join ', ')."
            $summary.mismatches++
        }
    }
}

foreach ($manifestView in @($manifest.views)) {
    $viewName = "$($manifestView.name)".Trim()
    $viewKey = $viewName.ToLowerInvariant()
    if (-not $viewName) { continue }

    if (@($currentState.views).Count -eq 0 -and -not $CurrentStatePath) {
        Add-Finding -FindingList $findings -Id 'VIEW_CHECK_UNAVAILABLE' -Severity 'low' -Category 'views' -Message "View '$viewName' cannot be validated without -CurrentStatePath export."
        $summary.unknownChecks++
        continue
    }

    if (-not $currentViewMap.ContainsKey($viewKey)) {
        Add-Action -ActionList $actions -Type 'create_view' -Name $viewName -Payload $manifestView
        $summary.plannedCreates++
        continue
    }

    $currentView = $currentViewMap[$viewKey]
    $expectedLayout = "$($manifestView.layout)".Trim().ToUpperInvariant()
    $actualLayout = "$($currentView.layout)".Trim().ToUpperInvariant()
    if ($expectedLayout -and $actualLayout -and $expectedLayout -ne $actualLayout) {
        Add-Finding -FindingList $findings -Id 'VIEW_LAYOUT_MISMATCH' -Severity 'medium' -Category 'views' -Message "View '$viewName' layout mismatch. Expected '$expectedLayout', found '$actualLayout'."
        $summary.mismatches++
    }

    if ($manifestView.PSObject.Properties.Name -contains 'groupBy') {
        $expectedGroupBy = "$($manifestView.groupBy)".Trim()
        $actualGroupBy = "$($currentView.groupBy)".Trim()
        if ($expectedGroupBy -ne $actualGroupBy) {
            Add-Finding -FindingList $findings -Id 'VIEW_GROUPBY_MISMATCH' -Severity 'medium' -Category 'views' -Message "View '$viewName' groupBy mismatch. Expected '$expectedGroupBy', found '$actualGroupBy'."
            $summary.mismatches++
        }
    }

    if ($manifestView.PSObject.Properties.Name -contains 'filters') {
        $expectedFilters = Normalize-StringArray -Value @($manifestView.filters)
        $actualFilters = Normalize-StringArray -Value @($currentView.filters)
        if (($expectedFilters -join '||') -ne ($actualFilters -join '||')) {
            Add-Finding -FindingList $findings -Id 'VIEW_FILTERS_MISMATCH' -Severity 'medium' -Category 'views' -Message "View '$viewName' filters mismatch. Expected '$($expectedFilters -join ', ')', found '$($actualFilters -join ', ')'."
            $summary.mismatches++
        }
    }
}

foreach ($manifestRule in @($manifest.rules)) {
    $ruleId = "$($manifestRule.id)".Trim()
    $ruleName = "$($manifestRule.name)".Trim()
    $ruleKey = $ruleId.ToLowerInvariant()
    if (-not $ruleId) { continue }

    if (@($currentState.rules).Count -eq 0 -and -not $CurrentStatePath) {
        Add-Finding -FindingList $findings -Id 'RULE_CHECK_UNAVAILABLE' -Severity 'low' -Category 'rules' -Message "Rule '$ruleName' cannot be validated without -CurrentStatePath export."
        $summary.unknownChecks++
        continue
    }

    if (-not $currentRuleMap.ContainsKey($ruleKey)) {
        Add-Action -ActionList $actions -Type 'create_rule' -Name $ruleName -Payload $manifestRule
        $summary.plannedCreates++
        continue
    }

    $currentRule = $currentRuleMap[$ruleKey]
    if ("$($currentRule.name)".Trim() -ne $ruleName) {
        Add-Finding -FindingList $findings -Id 'RULE_NAME_MISMATCH' -Severity 'medium' -Category 'rules' -Message "Rule '$ruleId' name mismatch. Expected '$ruleName', found '$($currentRule.name)'."
        $summary.mismatches++
    }

    foreach ($prop in @('mode', 'required')) {
        if ($manifestRule.PSObject.Properties.Name -contains $prop) {
            $expected = "$($manifestRule.$prop)".Trim().ToLowerInvariant()
            $actual = ''
            if ($currentRule.PSObject.Properties.Name -contains $prop) {
                $actual = "$($currentRule.$prop)".Trim().ToLowerInvariant()
            }
            if ($expected -ne $actual) {
                Add-Finding -FindingList $findings -Id "RULE_$($prop.ToUpper())_MISMATCH" -Severity 'medium' -Category 'rules' -Message "Rule '$ruleId' $prop mismatch. Expected '$expected', found '$actual'."
                $summary.mismatches++
            }
        }
    }
}

if ($Mode -eq 'apply') {
    foreach ($action in $actions) {
        switch ($action.type) {
            'create_field' {
                if ($usingLiveProject) {
                    $payload = $action.payload
                    $dataType = switch (Normalize-FieldType -Value "$($payload.type)") {
                        'single_select' { 'SINGLE_SELECT' }
                        'text' { 'TEXT' }
                        'number' { 'NUMBER' }
                        'date' { 'DATE' }
                        'iteration' { $null }
                        default { $null }
                    }

                    if (-not $dataType) {
                        Add-Finding -FindingList $findings -Id 'FIELD_APPLY_UNSUPPORTED_TYPE' -Severity 'medium' -Category 'fields' -Message "Field '$($payload.name)' uses type '$($payload.type)' that cannot be created via gh project field-create."
                        $action.status = 'skipped'
                        $summary.skippedNoOp++
                        continue
                    }

                    $cmdArgs = @('project', 'field-create', "$ProjectNumber", '--owner', $Owner, '--name', "$($payload.name)", '--data-type', $dataType)
                    if ($dataType -eq 'SINGLE_SELECT') {
                        $optionNames = Get-OptionNames -Field $payload
                        if (@($optionNames).Count -gt 0) {
                            $cmdArgs += @('--single-select-options', ($optionNames -join ','))
                        }
                    }

                    & gh @cmdArgs | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed creating field '$($payload.name)' in project $Owner/$ProjectNumber"
                    }
                } elseif ($CurrentStatePath) {
                    $currentState.fields += $action.payload
                }
                $action.status = 'applied'
                $summary.appliedCreates++
            }
            'create_view' {
                if ($CurrentStatePath) {
                    $currentState.views += $action.payload
                    $action.status = 'applied'
                    $summary.appliedCreates++
                } else {
                    $action.status = 'skipped'
                    $summary.skippedNoOp++
                }
            }
            'create_rule' {
                if ($CurrentStatePath) {
                    $currentState.rules += $action.payload
                    $action.status = 'applied'
                    $summary.appliedCreates++
                } else {
                    $action.status = 'skipped'
                    $summary.skippedNoOp++
                }
            }
            default {
                $action.status = 'skipped'
                $summary.skippedNoOp++
            }
        }
    }
}

if ($Mode -eq 'apply' -and $CurrentStatePath) {
    $resolvedStatePath = Resolve-Path $CurrentStatePath
    ($currentState | ConvertTo-Json -Depth 100) | Set-Content -Path $resolvedStatePath -Encoding UTF8
}

$report = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    mode = $Mode
    manifestPath = "$manifestFullPath"
    target = [ordered]@{
        owner = $Owner
        projectNumber = $ProjectNumber
        currentStatePath = $CurrentStatePath
        liveFieldBootstrap = $usingLiveProject
    }
    summary = $summary
    actions = @($actions)
    findings = @($findings)
}

Ensure-ParentDirectory -PathValue $JsonReportPath
Ensure-ParentDirectory -PathValue $MarkdownReportPath

($report | ConvertTo-Json -Depth 100) | Set-Content -Path $JsonReportPath -Encoding UTF8

$markdownLines = @(
    '# AIDL Portfolio Project Bootstrap Report',
    '',
    "Mode: **$Mode**",
    '',
    "| Metric | Value |",
    "|---|---|",
    "| Planned creates | $($summary.plannedCreates) |",
    "| Applied creates | $($summary.appliedCreates) |",
    "| Drift mismatches | $($summary.mismatches) |",
    "| Unknown checks | $($summary.unknownChecks) |",
    ''
)

if (@($actions).Count -gt 0) {
    $markdownLines += @(
        '## Planned or applied actions',
        '',
        '| Type | Name | Status |',
        '|---|---|---|'
    )
    foreach ($action in $actions) {
        $markdownLines += "| $($action.type) | $($action.name) | $($action.status) |"
    }
    $markdownLines += ''
}

if (@($findings).Count -gt 0) {
    $markdownLines += @(
        '## Drift findings',
        '',
        '| ID | Severity | Category | Finding |',
        '|---|---|---|---|'
    )
    foreach ($finding in $findings) {
        $markdownLines += "| $($finding.id) | $($finding.severity) | $($finding.category) | $($finding.message) |"
    }
    $markdownLines += ''
} else {
    $markdownLines += @(
        'No drift findings detected.',
        ''
    )
}

($markdownLines -join "`n") | Set-Content -Path $MarkdownReportPath -Encoding UTF8

Write-Host "Bootstrap report written: $JsonReportPath"
Write-Host "Bootstrap summary written: $MarkdownReportPath"

$driftDetected = (($summary.plannedCreates + $summary.mismatches) -gt 0)
if (($Mode -eq 'validate' -or $FailOnDrift) -and $driftDetected) {
    exit 1
}

exit 0

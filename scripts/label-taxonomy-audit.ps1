#Requires -Version 7.0
<#
.SYNOPSIS
    Validates the BaseCoat label taxonomy and reports label drift.

.DESCRIPTION
    Loads .github/governance/label-taxonomy.json and:
      1. Validates the registry (canonical, deprecated, and replacement entries agree).
      2. Rejects workflows, scripts, and issue templates that write a deprecated label.
      3. Optionally compares a live label set (-Repo or -LabelsJsonPath) against the
         registry and emits a Markdown drift report with the proposed migration
         operations. The report never changes labels.

.NOTES
    -Repo reads live labels with `gh label list`; -LabelsJsonPath reads an offline export.
    -ReportPath writes the report to a file; -FailOnDrift exits 1 on deprecated, unknown, or missing canonical labels.

.EXAMPLE
    pwsh scripts/label-taxonomy-audit.ps1
    pwsh scripts/label-taxonomy-audit.ps1 -Repo ivegamsft/basecoat -ReportPath label-drift.md
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$RegistryPath,
    [string]$Repo,
    [string]$LabelsJsonPath,
    [string]$ReportPath,
    [switch]$FailOnDrift
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $RegistryPath) {
    $RegistryPath = Join-Path $RepoRoot '.github/governance/label-taxonomy.json'
}

function Get-CanonicalLabelSet {
    param([Parameter(Mandatory)]$Taxonomy)
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($dimension in $Taxonomy.dimensions.PSObject.Properties) {
        if ($dimension.Value.PSObject.Properties['labels']) {
            foreach ($name in $dimension.Value.labels) { [void]$set.Add($name) }
        }
    }
    foreach ($name in @($Taxonomy.labels) + @($Taxonomy.onDemand) + @($Taxonomy.protectedLegacy.name)) {
        if ($name) { [void]$set.Add($name) }
    }
    return , $set
}

function Test-CanonicalLabel {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Taxonomy)
    if ((Get-CanonicalLabelSet -Taxonomy $Taxonomy).Contains($Name)) { return $true }
    foreach ($dimension in $Taxonomy.dimensions.PSObject.Properties) {
        if ($dimension.Value.PSObject.Properties['pattern'] -and $Name -cmatch $dimension.Value.pattern) { return $true }
    }
    return $false
}

function Resolve-DeprecatedLabel {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Taxonomy)
    $entry = @($Taxonomy.deprecated | Where-Object { $_.name -ceq $Name }) | Select-Object -First 1
    if ($entry) { return [pscustomobject]@{ Name = $Name; Replacement = $entry.replacement; Operation = $entry.operation } }
    foreach ($rule in @($Taxonomy.deprecatedPatterns)) {
        if ($Name -cmatch $rule.pattern) {
            return [pscustomobject]@{ Name = $Name; Replacement = ($Name -creplace $rule.pattern, $rule.replacement); Operation = $rule.operation }
        }
    }
    return $null
}

function Test-LabelTaxonomy {
    param([Parameter(Mandatory)]$Taxonomy)
    $errors = [System.Collections.Generic.List[string]]::new()
    $canonical = Get-CanonicalLabelSet -Taxonomy $Taxonomy
    foreach ($dimension in $Taxonomy.dimensions.PSObject.Properties) {
        if (-not $dimension.Value.PSObject.Properties['labels']) { continue }
        foreach ($name in $dimension.Value.labels) {
            if ($dimension.Name -notin @('type', 'resolution') -and $name -notlike "$($dimension.Name):*") {
                $errors.Add("Dimension '$($dimension.Name)' label '$name' must use the '$($dimension.Name):' prefix.")
            }
        }
    }
    foreach ($entry in @($Taxonomy.deprecated)) {
        if ($canonical.Contains($entry.name)) { $errors.Add("Label '$($entry.name)' is both canonical and deprecated.") }
        if ($entry.operation -notin @('rename', 'migrate-delete', 'remove')) {
            $errors.Add("Deprecated label '$($entry.name)' has unknown operation '$($entry.operation)'.")
        }
        if ($entry.operation -eq 'remove') { continue }
        if (-not $entry.replacement -or -not (Test-CanonicalLabel -Name $entry.replacement -Taxonomy $Taxonomy)) {
            $errors.Add("Deprecated label '$($entry.name)' maps to non-canonical '$($entry.replacement)'.")
        }
    }
    return , $errors
}

function Find-DeprecatedLabelWrite {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)]$Taxonomy)
    $codeContext = '(?i)(addLabels|Ensure-Label|--add-label|--label\b|label\s+(create|edit)|createLabel|labels?\s*[:=])'
    $deprecatedNames = @($Taxonomy.deprecated.name)
    $findings = [System.Collections.Generic.List[object]]::new()
    $files = foreach ($dir in '.github', 'scripts', 'skills', 'agents', 'prompts', 'instructions') {
        $path = Join-Path $Root $dir
        if (Test-Path $path) { Get-ChildItem -Path $path -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' } }
    }
    foreach ($file in $files) {
        $relative = [System.IO.Path]::GetRelativePath($Root, $file.FullName) -replace '\\', '/'
        $isPrompt = $file.Extension -eq '.md' -and $relative -match '^(\.github/(workflows|ISSUE_TEMPLATE)|agents|prompts|instructions|skills)/'
        if (-not $isPrompt -and $file.Extension -notin @('.yml', '.yaml', '.ps1', '.psm1', '.sh', '.cjs', '.js', '.mjs', '.py')) { continue }
        $lineNumber = 0
        $inWrite = $false
        foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
            $lineNumber++
            if ($isPrompt) {
                if ($line -notmatch '(?i)\b(add|apply|set|create|assign|attach)\w*\b.*label|label.*\b(add|apply|set|create|assign|attach)\w*\b' -or $line -match '(?i)legacy|alias|normaliz|migrat|deprecat') { continue }
                $literals = [regex]::Matches($line, '`([^`]+)`')
            } else {
                # YAML list items and bare array elements continue an open labels block; PowerShell @( ) lookup lists do not.
                $continues = $inWrite -and $line -match '^\s*(-\s+[^\s#]+\s*$|[''"][^''"]+[''"]\s*,?\s*[\])]*;?\s*$)'
                $isWrite = ($line -match $codeContext -and $line -notmatch '(?i)\b(list|search)\b[^|;&]*--label') -or $continues
                if (-not $isWrite) { $inWrite = $false; continue }
                $inWrite = $continues -or $line -match '(?i)((?<![\w$])labels?\s*:\s*\[?|addLabels\(\s*(\{\s*labels\s*:\s*)?\[?)\s*$'
                $literals = [regex]::Matches(($line -replace '(?i)(--remove-label[=\s]+|\blabel\s+edit\s+)(''[^'']*''|"[^"]*"|\S+)', ''), '''([^'']+)''|"([^"]+)"|`([^`]+)`|^\s*-\s+([^\s''"#]+)\s*$|(?i:label\s+create\s+|--(?:add-)?label[=\s]\s*|--name\s+)([^\s''"-][^\s''"]*)|\[([^\[\]''"]+)\]')
            }
            foreach ($value in @($literals | ForEach-Object { ($_.Groups | Select-Object -Skip 1 | Where-Object Success | Select-Object -First 1).Value -split '\s*,\s*' | Where-Object { $_ } })) {
                $wildcard = $value -replace '\$\{[^}]*\}|\$\([^)]*\)|\$[A-Za-z_][A-Za-z0-9_]*', '*'
                $hit = if ($wildcard -eq $value) {
                    if (Resolve-DeprecatedLabel -Name $value -Taxonomy $Taxonomy) { $value }
                } elseif ($wildcard.Trim('*')) {
                    $pattern = '^' + ([regex]::Escape($wildcard) -replace '\\\*', '[A-Za-z0-9._-]+') + '$'
                    $deprecatedNames | Where-Object { $_ -cmatch $pattern } | Select-Object -First 1
                }
                if ($hit) {
                    $findings.Add([pscustomobject]@{ Path = $relative; Line = $lineNumber; Value = $value; Deprecated = $hit })
                }
            }
        }
    }
    return , $findings
}

function Get-LabelDrift {
    param([Parameter(Mandatory)][string[]]$LiveLabels, [Parameter(Mandatory)]$Taxonomy)
    # Only the first alias may rename to an absent target; later aliases must migrate into it.
    $reserved = [System.Collections.Generic.HashSet[string]]::new([string[]]$LiveLabels, [StringComparer]::Ordinal)
    $deprecated = foreach ($name in $LiveLabels | Sort-Object) {
        $resolved = Resolve-DeprecatedLabel -Name $name -Taxonomy $Taxonomy
        if (-not $resolved) { continue }
        $operation = if ($resolved.Operation -eq 'remove') { 'remove' } elseif (-not $reserved.Add($resolved.Replacement)) { 'migrate-delete' } else { 'rename' }
        [pscustomobject]@{ Name = $name; Replacement = $resolved.Replacement; Operation = $operation }
    }
    $unknown = $LiveLabels | Sort-Object | Where-Object {
        -not (Test-CanonicalLabel -Name $_ -Taxonomy $Taxonomy) -and -not (Resolve-DeprecatedLabel -Name $_ -Taxonomy $Taxonomy)
    }
    $required = foreach ($dimension in $Taxonomy.dimensions.PSObject.Properties) { if ($dimension.Value.PSObject.Properties['labels']) { $dimension.Value.labels } }
    $missing = @($required) + @($Taxonomy.labels) | Where-Object { -not $reserved.Contains($_) }
    return [pscustomobject]@{ Deprecated = @($deprecated); Unknown = @($unknown); Missing = @($missing) }
}

function Format-LabelDriftReport {
    param([Parameter(Mandatory)]$Drift, [string]$Repo = 'repository')
    $lines = [System.Collections.Generic.List[string]]::new([string[]]@(
        "# Label Drift Report: $Repo", '',
        "Deprecated: $($Drift.Deprecated.Count). Unknown: $($Drift.Unknown.Count). Missing canonical: $($Drift.Missing.Count).",
        'Operations are proposals; follow docs/reference/label-taxonomy.md#migration-procedure and log items before any delete.',
        '', '## Proposed Operations', '', '| Label | Operation | Canonical |', '|---|---|---|'))
    foreach ($item in $Drift.Deprecated) {
        $target = if ($item.Replacement) { "``$($item.Replacement)``" } else { '(none)' }
        $lines.Add("| ``$($item.Name)`` | $($item.Operation) | $target |")
    }
    foreach ($section in @(@('Unknown Labels', $Drift.Unknown), @('Missing Canonical Labels', $Drift.Missing))) {
        $lines.AddRange([string[]]@('', "## $($section[0])", ''))
        if (@($section[1]).Count) { $section[1] | ForEach-Object { $lines.Add("- ``$_``") } } else { $lines.Add('- none') }
    }
    return ($lines -join "`n") + "`n"
}

if ($MyInvocation.InvocationName -eq '.') { return }

$taxonomy = Get-Content -Path $RegistryPath -Raw | ConvertFrom-Json
$failed = $false
$registryErrors = Test-LabelTaxonomy -Taxonomy $taxonomy
foreach ($message in $registryErrors) { Write-Host "Registry error: $message" -ForegroundColor Red; $failed = $true }
$writes = Find-DeprecatedLabelWrite -Root $RepoRoot -Taxonomy $taxonomy
foreach ($finding in $writes) {
    $replacement = (Resolve-DeprecatedLabel -Name $finding.Deprecated -Taxonomy $taxonomy).Replacement
    Write-Host "$($finding.Path):$($finding.Line) writes '$($finding.Value)', which matches deprecated label '$($finding.Deprecated)' (canonical: '$replacement')." -ForegroundColor Red
    $failed = $true
}
if (-not $failed) { Write-Host 'Label taxonomy registry is valid and no deprecated label writes were found.' }
if ($Repo -or $LabelsJsonPath) {
    $labelJson = if ($LabelsJsonPath) { Get-Content -Path $LabelsJsonPath -Raw } else {
        $output = gh label list -R $Repo -L 1000 --json name
        if ($LASTEXITCODE -ne 0) { throw "gh label list failed for $Repo." }
        $output -join "`n"
    }
    $drift = Get-LabelDrift -LiveLabels @(($labelJson | ConvertFrom-Json).name) -Taxonomy $taxonomy
    $report = Format-LabelDriftReport -Drift $drift -Repo $(if ($Repo) { $Repo } else { $LabelsJsonPath })
    if ($ReportPath) { Set-Content -Path $ReportPath -Value $report -NoNewline -Encoding utf8 } else { Write-Output $report }
    if ($FailOnDrift -and ($drift.Deprecated.Count -or $drift.Unknown.Count -or $drift.Missing.Count)) {
        Write-Host 'Live labels drift from the canonical taxonomy.' -ForegroundColor Red
        $failed = $true
    }
}

exit ([int]$failed)

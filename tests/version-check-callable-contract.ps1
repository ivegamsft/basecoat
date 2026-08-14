#!/usr/bin/env pwsh

# Contract test for the BaseCoat version-drift callable (#2812).
#
# Guards against the release regression where the documented/released caller
# passes a `source_repo` input (and `fetch_token` secret) that the callable
# does not declare, causing every downstream run to fail at startup with an
# "error parsing called workflow" / undeclared-input contract error.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

$callablePath = Join-Path $repoRoot '.github/workflows/check-basecoat-version-callable.yml'
$stagedPath = Join-Path $repoRoot '.github/base-coat/workflows/check-version.yml'
$docPaths = @(
    (Join-Path $repoRoot 'docs/guides/version-drift.md'),
    (Join-Path $repoRoot 'docs/getting-started.md')
)

$failures = @()

# The contract the released/documented caller relies on. Every one of these
# must be declared by the callable, or downstream startup fails.
$requiredInputs = @('stage_path', 'alert_threshold', 'source_repo')
$requiredSecrets = @('fetch_token')

function Get-DeclaredKeys {
    param(
        [string]$Content,
        [string]$Section  # 'inputs' or 'secrets'
    )
    # Scope to the workflow_call block, then to the requested sub-section.
    $lines = $Content -split "`r?`n"
    $keys = @()
    $inWorkflowCall = $false
    $inSection = $false
    foreach ($line in $lines) {
        if ($line -match '^\s{2}workflow_call:\s*$') { $inWorkflowCall = $true; continue }
        if (-not $inWorkflowCall) { continue }
        # A top-level `on:` sibling (2-space key) ends the workflow_call block.
        if ($line -match '^\S') { break }
        if ($line -match "^\s{4}${Section}:\s*$") { $inSection = $true; continue }
        if ($inSection) {
            if ($line -match '^\s{4}\S') { $inSection = $false; continue }  # sibling of section
            if ($line -match '^\s{6}([A-Za-z0-9_]+):\s*$') { $keys += $Matches[1] }
        }
    }
    return $keys
}

function Get-CallerWithKeys {
    param([string]$Content)
    # Extract `with:` mapping keys that appear under a `uses:` of the callable.
    $lines = $Content -split "`r?`n"
    $keys = @()
    $inWith = $false
    $withIndent = -1
    foreach ($line in $lines) {
        if ($line -match '^(\s*)with:\s*$') {
            $inWith = $true
            $withIndent = $Matches[1].Length
            continue
        }
        if ($inWith) {
            if ($line.Trim().Length -eq 0) { continue }
            $indent = ($line -replace '\S.*$', '').Length
            if ($indent -le $withIndent) { $inWith = $false; continue }
            if ($line -match '^\s*([A-Za-z0-9_]+):') { $keys += $Matches[1] }
        }
    }
    return $keys | Select-Object -Unique
}

function Get-InputAttribute {
    param(
        [string]$Content,
        [string]$InputName,
        [string]$Attribute  # e.g. 'required', 'default', 'type'
    )
    # Return the scalar value of an attribute declared under a given
    # workflow_call input (6-space key, 8-space attributes).
    $lines = $Content -split "`r?`n"
    $inInput = $false
    foreach ($line in $lines) {
        if ($line -match "^\s{6}${InputName}:\s*$") { $inInput = $true; continue }
        if ($inInput) {
            # A sibling 6-space input (or shallower) ends this input block.
            if ($line -match '^\s{0,6}\S') { break }
            if ($line -match "^\s{8}${Attribute}:\s*(.+?)\s*$") { return $Matches[1].Trim('"').Trim("'") }
        }
    }
    return $null
}

foreach ($path in @($callablePath, $stagedPath)) {
    if (-not (Test-Path $path)) {
        $failures += "Missing callable workflow: $path"
    }
}

if ($failures.Count -eq 0) {
    $callable = Get-Content $callablePath -Raw
    $staged = Get-Content $stagedPath -Raw

    $callableInputs = Get-DeclaredKeys -Content $callable -Section 'inputs'
    $callableSecrets = Get-DeclaredKeys -Content $callable -Section 'secrets'
    $stagedInputs = Get-DeclaredKeys -Content $staged -Section 'inputs'
    $stagedSecrets = Get-DeclaredKeys -Content $staged -Section 'secrets'

    foreach ($input in $requiredInputs) {
        if ($callableInputs -notcontains $input) {
            $failures += "Canonical callable must declare workflow_call input '$input'."
        }
        if ($stagedInputs -notcontains $input) {
            $failures += "Staged callable must declare workflow_call input '$input'."
        }
    }
    foreach ($secret in $requiredSecrets) {
        if ($callableSecrets -notcontains $secret) {
            $failures += "Canonical callable must declare workflow_call secret '$secret'."
        }
        if ($stagedSecrets -notcontains $secret) {
            $failures += "Staged callable must declare workflow_call secret '$secret'."
        }
    }

    # Schema parity: canonical and staged copies must declare the same contract.
    $inputDiff = @(Compare-Object -ReferenceObject ($callableInputs | Sort-Object) -DifferenceObject ($stagedInputs | Sort-Object))
    if ($inputDiff.Count -gt 0) {
        $failures += "Canonical and staged callables declare divergent inputs: $(( $inputDiff | ForEach-Object { $_.InputObject }) -join ', ')."
    }
    $secretDiff = @(Compare-Object -ReferenceObject ($callableSecrets | Sort-Object) -DifferenceObject ($stagedSecrets | Sort-Object))
    if ($secretDiff.Count -gt 0) {
        $failures += "Canonical and staged callables declare divergent secrets: $(( $secretDiff | ForEach-Object { $_.InputObject }) -join ', ')."
    }

    # Attribute parity for source_repo: it must be declared 'required: true' in
    # both copies (never derived from github.workflow_ref, which for a callable
    # distributed into a consumer resolves to the consumer, not to BaseCoat).
    foreach ($pair in @(
            @{ Name = 'Canonical'; Content = $callable },
            @{ Name = 'Staged'; Content = $staged })) {
        $required = Get-InputAttribute -Content $pair.Content -InputName 'source_repo' -Attribute 'required'
        $default = Get-InputAttribute -Content $pair.Content -InputName 'source_repo' -Attribute 'default'
        if ($required -ne 'true') {
            $failures += "$($pair.Name) callable must declare source_repo as 'required: true' (found '$required'); it must not be optional with a workflow_ref fallback."
        }
        if ($null -ne $default) {
            $failures += "$($pair.Name) callable must not give source_repo a default ('$default'); require it explicitly so the source is never silently derived from the caller."
        }
    }

    # Every documented caller must only pass inputs the callable declares.
    foreach ($docPath in $docPaths) {
        if (-not (Test-Path $docPath)) { continue }
        $doc = Get-Content $docPath -Raw
        if ($doc -notmatch 'check-basecoat-version-callable\.yml') { continue }
        $withKeys = Get-CallerWithKeys -Content $doc
        foreach ($key in $withKeys) {
            if ($callableInputs -notcontains $key) {
                $failures += "Documented caller in $(Split-Path $docPath -Leaf) passes undeclared input '$key'."
            }
        }
        if ($withKeys -notcontains 'source_repo') {
            $failures += "Documented caller in $(Split-Path $docPath -Leaf) must demonstrate the 'source_repo' input."
        }
    }

    # Every documented caller example of either callable — including local
    # `uses:` of the staged copy — must pass the required 'source_repo' input,
    # or a consumer copying the example hits the required-input startup failure
    # (GitHub validates required reusable-workflow inputs before jobs start).
    $callerDocPaths = @(
        (Join-Path $repoRoot 'docs/guides/version-drift.md'),
        (Join-Path $repoRoot 'docs/getting-started.md'),
        (Join-Path $repoRoot 'docs/guides/workflows-reference.md')
    )
    foreach ($docPath in $callerDocPaths) {
        if (-not (Test-Path $docPath)) { continue }
        $doc = Get-Content $docPath -Raw
        $blocks = [regex]::Matches($doc, '(?s)```[a-zA-Z]*\r?\n(.*?)```')
        foreach ($m in $blocks) {
            $block = $m.Groups[1].Value
            if ($block -notmatch 'check-basecoat-version-callable\.yml|workflows/check-version\.yml') { continue }
            if ($block -notmatch '(?m)^\s*source_repo\s*:') {
                $failures += "Documented caller example in $(Split-Path $docPath -Leaf) invokes the version-check callable without passing the required 'source_repo' input."
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Version-check callable contract FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Version-check callable contract passed.' -ForegroundColor Green

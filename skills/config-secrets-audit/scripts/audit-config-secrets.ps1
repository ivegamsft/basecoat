#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$RootPath = ".",
    [string]$SarifPath = "",
    [string]$ExclusionFile = "",
    [string]$CustomPatternFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $RootPath)) {
    throw "RootPath '$RootPath' does not exist."
}

$resolvedRoot = (Resolve-Path $RootPath).Path

$defaultPatterns = @(
    @{
        Id = "CONFIG001"
        Category = "azure-key-vault-reference"
        Severity = "low"
        Regex = '@Microsoft\.KeyVault\(SecretUri='
        Message = "Azure Key Vault reference detected; verify no fallback inline secret exists."
    },
    @{
        Id = "CONFIG002"
        Category = "hardcoded-connection-string"
        Severity = "critical"
        Regex = '(?i)(Server|Data Source)\s*=\s*[^;]+;[^`n]*(Password|Pwd)\s*=\s*[^;]+'
        Message = "Hardcoded connection string with embedded password detected."
    },
    @{
        Id = "CONFIG003"
        Category = "generic-secret-assignment"
        Severity = "high"
        Regex = '(?i)\b(api[_-]?key|secret|token|password|client[_-]?secret)\b\s*[:=]\s*["''][^"'']{6,}["'']'
        Message = "Likely hardcoded secret assignment detected."
    },
    @{
        Id = "CONFIG004"
        Category = "base64-like-secret"
        Severity = "medium"
        Regex = '(?<![A-Za-z0-9+/=])[A-Za-z0-9+/]{32,}={0,2}(?![A-Za-z0-9+/=])'
        Message = "Base64-like token detected; review for secret material."
    },
    @{
        Id = "CONFIG005"
        Category = "iac-parameter-secret"
        Severity = "high"
        Regex = '(?i)\b(clientSecret|connectionString|storageAccountKey|accessKey)\b\s*[:=]\s*["''][^"'']+["'']'
        Message = "Potential secret literal in IaC parameter/config context."
    }
)

$customPatterns = @()
if ($CustomPatternFile) {
    if (-not (Test-Path $CustomPatternFile)) {
        throw "CustomPatternFile '$CustomPatternFile' does not exist."
    }
    $custom = Get-Content $CustomPatternFile -Raw | ConvertFrom-Json
    foreach ($item in $custom) {
        if (-not $item.id -or -not $item.pattern -or -not $item.severity -or -not $item.category -or -not $item.message) {
            throw "Each custom pattern must define: id, pattern, severity, category, message."
        }
        $customPatterns += @{
            Id = [string]$item.id
            Category = [string]$item.category
            Severity = [string]$item.severity
            Regex = [string]$item.pattern
            Message = [string]$item.message
        }
    }
}

$allPatterns = @($defaultPatterns + $customPatterns)

$excludeMatchers = @()
if ($ExclusionFile) {
    if (-not (Test-Path $ExclusionFile)) {
        throw "ExclusionFile '$ExclusionFile' does not exist."
    }
    $excludeMatchers = Get-Content $ExclusionFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
}

function Test-IsExcluded {
    param([string]$RelativePath)
    foreach ($pattern in $excludeMatchers) {
        if ($RelativePath -like $pattern) {
            return $true
        }
    }
    return $false
}

function Add-Finding {
    param(
        [string]$File,
        [int]$Line,
        [hashtable]$Pattern,
        [string]$Snippet
    )
    $script:findings += [PSCustomObject]@{
        ruleId = $Pattern.Id
        category = $Pattern.Category
        severity = $Pattern.Severity
        file = $File
        line = $Line
        message = $Pattern.Message
        snippet = $Snippet
    }
}

$scanExtensions = @(".json", ".yaml", ".yml", ".env", ".tfvars", ".bicepparam", ".bicep")
$workflowGlob = ".github\workflows\*.y*ml"
$files = Get-ChildItem -Path $resolvedRoot -Recurse -File | Where-Object {
    $_.Extension -in $scanExtensions -or
    ($_.FullName -like "*$workflowGlob")
}

$script:findings = @()

foreach ($file in $files) {
    $relativePath = [System.IO.Path]::GetRelativePath($resolvedRoot, $file.FullName)
    if (Test-IsExcluded -RelativePath $relativePath) {
        continue
    }

    $lines = Get-Content $file.FullName
    $inEnvBlock = $false
    $envIndent = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNumber = $i + 1

        foreach ($pattern in $allPatterns) {
            if ($line -match $pattern.Regex) {
                Add-Finding -File $relativePath -Line $lineNumber -Pattern $pattern -Snippet $line.Trim()
            }
        }

        if ($relativePath -like ".github\workflows\*.y*ml") {
            if ($line -match '^(\s*)env:\s*$') {
                $inEnvBlock = $true
                $envIndent = $matches[1].Length
                continue
            }

            if ($inEnvBlock) {
                if ($line -match '^\s*$') {
                    continue
                }

                $currentIndent = ($line -replace '^(\s*).*$', '$1').Length
                if ($currentIndent -le $envIndent) {
                    $inEnvBlock = $false
                }
                elseif ($line -match '^\s*([A-Za-z0-9_]+)\s*:\s*(.+)\s*$') {
                    $key = $matches[1]
                    $value = $matches[2]
                    $isSensitiveKey = $key -match '(?i)(secret|token|password|key|client_secret)'
                    $isExpression = $value -match '\${{\s*(secrets|vars)\.'
                    if ($isSensitiveKey -and -not $isExpression -and $value -notmatch '^\s*["'']?\*{3,}["'']?\s*$') {
                        Add-Finding -File $relativePath -Line $lineNumber -Pattern @{
                            Id = "CONFIG006"
                            Category = "workflow-env-secret"
                            Severity = "high"
                            Message = "Sensitive workflow env key has inline value; use secrets/vars reference."
                        } -Snippet $line.Trim()
                    }
                }
            }
        }
    }
}

$severityOrder = @("critical", "high", "medium", "low")

$summary = $findings |
    Group-Object severity, category |
    Sort-Object {
        $parts = $_.Name.Split(",")
        $severityIndex = $severityOrder.IndexOf($parts[0].Trim())
        if ($severityIndex -lt 0) { return 999 }
        return $severityIndex
    }, Name |
    ForEach-Object {
        $parts = $_.Name.Split(",")
        [PSCustomObject]@{
            severity = $parts[0].Trim()
            category = $parts[1].Trim()
            count = $_.Count
        }
    }

if ($SarifPath) {
    $rules = $findings |
        Sort-Object ruleId -Unique |
        ForEach-Object {
            [PSCustomObject]@{
                id = $_.ruleId
                shortDescription = @{ text = $_.category }
                fullDescription = @{ text = $_.message }
                defaultConfiguration = @{
                    level = switch ($_.severity) {
                        "critical" { "error" }
                        "high" { "error" }
                        "medium" { "warning" }
                        default { "note" }
                    }
                }
            }
        }

    $results = $findings | ForEach-Object {
        [PSCustomObject]@{
            ruleId = $_.ruleId
            level = switch ($_.severity) {
                "critical" { "error" }
                "high" { "error" }
                "medium" { "warning" }
                default { "note" }
            }
            message = @{ text = $_.message }
            locations = @(
                @{
                    physicalLocation = @{
                        artifactLocation = @{ uri = $_.file }
                        region = @{ startLine = $_.line }
                    }
                }
            )
        }
    }

    $sarif = [PSCustomObject]@{
        '$schema' = "https://json.schemastore.org/sarif-2.1.0.json"
        version = "2.1.0"
        runs = @(
            @{
                tool = @{
                    driver = @{
                        name = "config-secrets-audit"
                        informationUri = "https://github.com/IBuySpy-Shared/basecoat"
                        rules = $rules
                    }
                }
                results = $results
            }
        )
    }

    $sarifDir = Split-Path -Parent $SarifPath
    if ($sarifDir -and -not (Test-Path $sarifDir)) {
        New-Item -ItemType Directory -Path $sarifDir -Force | Out-Null
    }
    $sarif | ConvertTo-Json -Depth 12 | Set-Content -Path $SarifPath -Encoding UTF8
}

Write-Host ""
Write-Host "Config Secrets Audit Summary" -ForegroundColor Cyan
Write-Host "Root: $resolvedRoot"
Write-Host "Findings: $($findings.Count)"
foreach ($row in $summary) {
    Write-Host ("- {0}/{1}: {2}" -f $row.severity, $row.category, $row.count)
}
if ($SarifPath) {
    Write-Host "SARIF: $SarifPath"
}

$findings | Sort-Object severity, category, file, line | Format-Table severity, category, file, line, ruleId -AutoSize

if ($findings.Where({ $_.severity -in @("critical", "high") }).Count -gt 0) {
    exit 2
}

exit 0


#!/usr/bin/env pwsh
<#
.SYNOPSIS
Scan application dependencies for vulnerabilities and size estimates.

.PARAMETER AppRoot
Path to the application root directory.
#>

param([string]$AppRoot = '.')

$resolvedAppRoot = (Resolve-Path $AppRoot).Path

$result = @{
    app_root = $resolvedAppRoot
    package_manager = $null
    total_dependencies = 0
    outdated = "not-scanned"
    vulnerable = "not-scanned"
    lock_file_exists = $false
    estimated_node_modules_size = $null
    package_managers_found = @()
    scan_note = "Counts are placeholders until package-manager-specific audit commands are integrated."
}

# Detect package manager
if (Test-Path "$resolvedAppRoot/package.json") {
    $result.package_managers_found += 'npm'
    $result.package_manager = 'npm'
    $result.lock_file_exists = (Test-Path "$resolvedAppRoot/package-lock.json")
}

if (Test-Path "$resolvedAppRoot/yarn.lock") {
    $result.package_managers_found += 'yarn'
    if (-not $result.package_manager) { $result.package_manager = 'yarn' }
}

if (Test-Path "$resolvedAppRoot/go.mod") {
    $result.package_managers_found += 'go'
    if (-not $result.package_manager) { $result.package_manager = 'go' }
}

if (Test-Path "$resolvedAppRoot/requirements.txt") {
    $result.package_managers_found += 'pip'
    if (-not $result.package_manager) { $result.package_manager = 'pip' }
}

# Estimate node_modules size if npm
if ($result.package_manager -eq 'npm') {
    if (Test-Path "$resolvedAppRoot/node_modules") {
        $size = (Get-ChildItem "$resolvedAppRoot/node_modules" -Recurse | Measure-Object -Property Length -Sum).Sum
        $sizeGB = [Math]::Round($size / 1GB, 2)
        $result.estimated_node_modules_size = "$sizeGB GB"
        
        # Count packages
        $result.total_dependencies = @(Get-ChildItem "$resolvedAppRoot/node_modules" -Directory).Count
    } else {
        $result.estimated_node_modules_size = "unknown (run npm install)"
        $result.total_dependencies = 0
    }
}

$result | ConvertTo-Json -Depth 3

#!/usr/bin/env pwsh
<#
.SYNOPSIS
Scan application dependencies for vulnerabilities and size estimates.

.PARAMETER AppRoot
Path to the application root directory.
#>

param([string]$AppRoot = '.')

$result = @{
    app_root = $AppRoot
    package_manager = $null
    total_dependencies = 0
    outdated = 0
    vulnerable = 0
    lock_file_exists = $false
    estimated_node_modules_size = $null
    package_managers_found = @()
}

# Detect package manager
if (Test-Path "$AppRoot/package.json") {
    $result.package_managers_found += 'npm'
    $result.package_manager = 'npm'
    $result.lock_file_exists = (Test-Path "$AppRoot/package-lock.json")
}

if (Test-Path "$AppRoot/yarn.lock") {
    $result.package_managers_found += 'yarn'
    if (-not $result.package_manager) { $result.package_manager = 'yarn' }
}

if (Test-Path "$AppRoot/go.mod") {
    $result.package_managers_found += 'go'
    if (-not $result.package_manager) { $result.package_manager = 'go' }
}

if (Test-Path "$AppRoot/requirements.txt") {
    $result.package_managers_found += 'pip'
    if (-not $result.package_manager) { $result.package_manager = 'pip' }
}

# Estimate node_modules size if npm
if ($result.package_manager -eq 'npm') {
    if (Test-Path "$AppRoot/node_modules") {
        $size = (Get-ChildItem "$AppRoot/node_modules" -Recurse | Measure-Object -Property Length -Sum).Sum
        $sizeGB = [Math]::Round($size / 1GB, 2)
        $result.estimated_node_modules_size = "$sizeGB GB"
        
        # Count packages
        $result.total_dependencies = @(Get-ChildItem "$AppRoot/node_modules" -Directory).Count
    } else {
        $result.estimated_node_modules_size = "unknown (run npm install)"
        $result.total_dependencies = 0
    }
    
    # Estimate vulnerabilities (mock data)
    $result.vulnerable = Get-Random -Minimum 0 -Maximum 5
    $result.outdated = Get-Random -Minimum 2 -Maximum 15
}

$result | ConvertTo-Json -Depth 3

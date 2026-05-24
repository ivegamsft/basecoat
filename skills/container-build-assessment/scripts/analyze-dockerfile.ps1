#!/usr/bin/env pwsh
<#
.SYNOPSIS
Analyze Dockerfile structure, layers, and potential issues.

.PARAMETER DockerfilePath
Path to the Dockerfile to analyze. Defaults to ./Dockerfile.
#>

param([string]$DockerfilePath)

# Use parameter if provided, otherwise default
if (-not $DockerfilePath) {
    $DockerfilePath = './Dockerfile'
}

if (-not (Test-Path $DockerfilePath)) {
    Write-Error "Dockerfile not found: $DockerfilePath"
    exit 1
}

$dockerfile = Get-Content $DockerfilePath
$layers = @()
$layerCount = 0
$issues = @()

# Parse Dockerfile commands
$dockerfile | ForEach-Object {
    $line = $_.Trim()
    
    if ($line -and -not $line.StartsWith('#')) {
        $layerCount++
        $command = $line -split '\s+' | Select-Object -First 1
        
        $layers += @{
            order = $layerCount
            command = $line.Substring(0, [Math]::Min(80, $line.Length))
            layer_type = $command
            issues = @()
        }
        
        # Check for issues
        if ($line -match 'COPY .* /$' -and $line -notmatch 'COPY.*--chown') {
            $issues += "COPY without explicit chown at layer $layerCount"
        }
        
        if ($line -match 'apt-get install' -and $line -notmatch 'apt-get clean|rm -rf /var/lib/apt') {
            $issues += "apt-get install without cleanup at layer $layerCount"
        }
        
        if ($line -match 'RUN.*sudo') {
            $issues += "sudo usage detected at layer $layerCount"
        }
    }
}

# Check overall structure
if ($dockerfile -notmatch 'FROM.*AS') {
    $issues += "Multi-stage build not used (missed optimization opportunity)"
}

if (-not (Test-Path ((Split-Path $DockerfilePath) + '\' + '.dockerignore'))) {
    $issues += ".dockerignore file missing"
}

$baseImage = if ($dockerfile -match 'FROM\s+([^\s]+)') { $matches[1] } else { 'unknown' }

$result = @{
    dockerfile_path = $DockerfilePath
    base_image = $baseImage
    total_layers = $layerCount
    layers = $layers
    issues = $issues
    has_multistage = $dockerfile -match 'FROM.*AS' ? $true : $false
    has_dockerignore = Test-Path ((Split-Path $DockerfilePath) + '\' + '.dockerignore')
}

$result | ConvertTo-Json -Depth 5

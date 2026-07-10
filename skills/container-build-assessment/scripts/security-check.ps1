#!/usr/bin/env pwsh
<#
.SYNOPSIS
Security check for Docker image: root user, secrets, latest tags, health checks.

.PARAMETER DockerfilePath
Path to the Dockerfile to analyze.
#>

param([string]$DockerfilePath = './Dockerfile')

if (-not (Test-Path $DockerfilePath)) {
    Write-Error "Dockerfile not found: $DockerfilePath"
    exit 1
}

$dockerfile = Get-Content $DockerfilePath -Raw
$issues = @()
$runsAsRoot = $true
$containsSecrets = $false
$usesLatestTags = $false
$hasHealthCheck = $false

# Check if non-root user is set
if ($dockerfile -match 'USER\s+\w+') {
    $runsAsRoot = $false
}

# Check for embedded secrets
if ($dockerfile -match 'ENV\s+.*PASSWORD|ENV\s+.*SECRET|ENV\s+.*KEY|RUN.*export\s+.*=.*["\']') {
    $containsSecrets = $true
    $issues += @{
        severity = "high"
        issue = "Potential secrets embedded in Dockerfile"
        fix = "Use Docker build secrets or environment variables from .env files"
    }
}

# Check for latest tags
if ($dockerfile -match 'FROM.*:latest|apt-get install.*latest') {
    $usesLatestTags = $true
    $issues += @{
        severity = "medium"
        issue = "Using :latest tag for base image (not pinned to version)"
        fix = "Pin to specific version: FROM node:18.17.0"
    }
}

# Check for health check
if ($dockerfile -match 'HEALTHCHECK') {
    $hasHealthCheck = $true
}

# Check if runs as root
if ($runsAsRoot) {
    $issues += @{
        severity = "high"
        issue = "Container runs as root user (security risk)"
        fix = "Add USER directive: USER appuser (non-root)"
    }
}

# Check for apt-get without cleanup
if ($dockerfile -match 'apt-get install' -and $dockerfile -notmatch 'rm -rf /var/lib/apt/lists') {
    $issues += @{
        severity = "low"
        issue = "apt-get install leaves cache (increases layer size)"
        fix = "Combine with: && rm -rf /var/lib/apt/lists/*"
    }
}

$result = @{
    dockerfile_path = $DockerfilePath
    runs_as_root = $runsAsRoot
    contains_secrets = $containsSecrets
    uses_latest_tags = $usesLatestTags
    has_health_check = $hasHealthCheck
    issues = $issues
    score = [Math]::Max(0, 100 - ($issues.Count * 10))
}

$result | ConvertTo-Json -Depth 5

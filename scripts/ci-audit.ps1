param(
    [string]$OrgName,
    [ValidateSet('json', 'markdown')]
    [string]$OutputFormat = 'markdown',
    [string]$OutputPath,
    [switch]$IncludeEnterpriseSettings,
    [int]$OutdatedThresholdDays = 180,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Help {
    Write-Host @"
CI/CD Audit Script

Audits GitHub organization CI/CD settings, dependencies, runners, and apps.

USAGE:
    ./scripts/ci-audit.ps1 -OrgName <org> [-OutputFormat json|markdown] [-OutputPath <path>]

OPTIONS:
    -OrgName <string>                  GitHub organization name (required)
    -OutputFormat <string>             Output format: 'json' or 'markdown' (default: markdown)
    -OutputPath <string>               Path to write output file (optional; defaults to stdout)
    -IncludeEnterpriseSettings         Include enterprise-level settings (requires enterprise access)
    -OutdatedThresholdDays <int>       Days threshold for marking dependencies as outdated (default: 180)
    -Help                              Show this help message

EXAMPLES:
    ./scripts/ci-audit.ps1 -OrgName my-org
    ./scripts/ci-audit.ps1 -OrgName my-org -OutputFormat json -OutputPath ./audit-report.json
    ./scripts/ci-audit.ps1 -OrgName my-org -IncludeEnterpriseSettings
"@
}

if ($Help -or -not $OrgName) {
    Show-Help
    if ($Help) { exit 0 }
    Write-Error 'OrgName is required'
    exit 1
}

function Write-AuditLog {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

function Invoke-GhApi {
    param(
        [string]$Endpoint,
        [string]$Method = 'GET'
    )
    try {
        $result = gh api $Endpoint --method $Method 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-AuditLog "API request failed: $result" 'WARN'
            return $null
        }
        return $result | ConvertFrom-Json
    }
    catch {
        Write-AuditLog "Error parsing API response: $_" 'WARN'
        return $null
    }
}

Write-AuditLog "Starting CI/CD audit for organization: $OrgName"

$auditTimestamp = Get-Date -Format 'o'
$findings = @{
    org_settings     = @{ findings = @() }
    enterprise_settings = @{ findings = @() }
    dependencies     = @{ findings = @(); outdated_packages = @() }
    runners          = @{ findings = @(); runner_profiles = @() }
    apps_sdks        = @{ findings = @(); app_inventory = @() }
}

Write-AuditLog 'Auditing organization settings...'
$orgSettings = Invoke-GhApi "orgs/$OrgName"
if ($orgSettings) {
    if (-not $orgSettings.secret_scanning_push_protection_custom_properties_enabled) {
        $findings.org_settings.findings += @{
            id          = 'ORG-001'
            severity    = 'high'
            category    = 'Secrets'
            title       = 'Secret push protection not enabled'
            description = 'Secret scanning push protection is not enabled for the organization'
            recommendation = 'Enable secret scanning push protection in org settings'
        }
    }
    Write-AuditLog "Organization settings audit complete: $($orgSettings.name)"
}
else {
    $findings.org_settings.findings += @{
        id          = 'ORG-002'
        severity    = 'medium'
        category    = 'General'
        title       = 'Unable to query organization settings'
        description = 'Could not retrieve organization settings via GitHub API'
        recommendation = 'Verify credentials and organization access'
    }
}

if ($IncludeEnterpriseSettings) {
    Write-AuditLog 'Auditing enterprise settings...'
    $enterprise = Invoke-GhApi "enterprises" --method GET
    if ($enterprise) {
        $findings.enterprise_settings.findings += @{
            id          = 'ENT-001'
            severity    = 'medium'
            category    = 'General'
            title       = 'Enterprise settings available'
            description = 'Enterprise settings audit is available'
            recommendation = 'Review enterprise governance policies'
        }
    }
}

Write-AuditLog 'Auditing dependencies...'
$workflowFiles = @()
if (Test-Path '.github/workflows') {
    $workflowFiles = Get-ChildItem '.github/workflows' -Filter '*.yml', '*.yaml' -Recurse
    Write-AuditLog "Found $($workflowFiles.Count) workflow files"
}

if (Test-Path 'package.json') {
    $packageJson = Get-Content 'package.json' | ConvertFrom-Json
    $devDeps = $packageJson.devDependencies | Get-Member -MemberType NoteProperty
    Write-AuditLog "Node.js project with $($devDeps.Count) dependencies detected"
    
    if (-not (Test-Path 'package-lock.json')) {
        $findings.dependencies.findings += @{
            id          = 'DEP-001'
            severity    = 'medium'
            category    = 'Lock Files'
            title       = 'Missing package-lock.json'
            description = 'npm project lacks a lock file for dependency pinning'
            recommendation = 'Generate package-lock.json with npm install'
        }
    }
}

if (Test-Path 'requirements.txt') {
    Write-AuditLog 'Python project detected (requirements.txt)'
    if (-not (Test-Path 'requirements.lock')) {
        $findings.dependencies.findings += @{
            id          = 'DEP-002'
            severity    = 'medium'
            category    = 'Lock Files'
            title       = 'Missing requirements.lock'
            description = 'Python project lacks a lock file for dependency pinning'
            recommendation = 'Generate lock file with pip-tools or poetry'
        }
    }
}

Write-AuditLog 'Auditing self-hosted runners...'
$runners = Invoke-GhApi "orgs/$OrgName/actions/runners"
if ($runners -and $runners.runners) {
    Write-AuditLog "Found $($runners.runners.Count) self-hosted runners"
    foreach ($runner in $runners.runners) {
        $findings.runners.runner_profiles += @{
            name              = $runner.name
            status            = $runner.status
            os                = $runner.os
            busy              = $runner.busy
            last_seen_at      = $runner.last_seen_at
            runner_group_id   = $runner.runner_group_id
        }
    }
    
    $offlineRunners = @($runners.runners | Where-Object { $_.status -ne 'online' })
    if ($offlineRunners.Count -gt 0) {
        $findings.runners.findings += @{
            id          = 'RUN-001'
            severity    = 'medium'
            category    = 'Runner Status'
            title       = "Found $($offlineRunners.Count) offline runners"
            description = "There are $($offlineRunners.Count) runners that are not online"
            recommendation = 'Review and decommission runners offline for >30 days'
        }
    }
}
else {
    Write-AuditLog 'No self-hosted runners found or insufficient access'
}

Write-AuditLog 'Auditing installed apps...'
$apps = Invoke-GhApi "orgs/$OrgName/installations"
if ($apps -and $apps.installations) {
    Write-AuditLog "Found $($apps.installations.Count) installed apps"
    foreach ($app in $apps.installations) {
        $findings.apps_sdks.app_inventory += @{
            app_name    = $app.app_slug
            id          = $app.id
            permissions = ($app.permissions | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
        }
    }
}
else {
    Write-AuditLog 'No apps found or insufficient access'
}

$totalCritical = @($findings.Values | ForEach-Object { $_.findings } | Where-Object { $_.severity -eq 'critical' }).Count
$totalHigh = @($findings.Values | ForEach-Object { $_.findings } | Where-Object { $_.severity -eq 'high' }).Count
$totalMedium = @($findings.Values | ForEach-Object { $_.findings } | Where-Object { $_.severity -eq 'medium' }).Count
$totalLow = @($findings.Values | ForEach-Object { $_.findings } | Where-Object { $_.severity -eq 'low' }).Count
$totalFindings = @($findings.Values | ForEach-Object { $_.findings }).Count

$summary = @{
    total_findings  = $totalFindings
    critical_count  = $totalCritical
    high_count      = $totalHigh
    medium_count    = $totalMedium
    low_count       = $totalLow
}

$report = @{
    audit_timestamp  = $auditTimestamp
    org_name         = $OrgName
    audit_sections   = $findings
    summary          = $summary
}

Write-AuditLog "Audit complete. Found $totalFindings findings (Critical: $totalCritical, High: $totalHigh, Medium: $totalMedium, Low: $totalLow)"

if ($OutputFormat -eq 'json') {
    $output = $report | ConvertTo-Json -Depth 10
}
else {
    $output = @"
# CI/CD Audit Report

**Organization:** $($report.org_name)
**Audit Timestamp:** $($report.audit_timestamp)

## Executive Summary

- **Total Findings:** $($report.summary.total_findings)
- **Critical:** $($report.summary.critical_count)
- **High:** $($report.summary.high_count)
- **Medium:** $($report.summary.medium_count)
- **Low:** $($report.summary.low_count)

## Organization Settings

$(@($report.audit_sections.org_settings.findings | ForEach-Object { "- [$($_.severity.ToUpper())] $($_.title): $($_.description)" }) -join "`n")

## Dependencies

$(@($report.audit_sections.dependencies.findings | ForEach-Object { "- [$($_.severity.ToUpper())] $($_.title): $($_.description)" }) -join "`n")

## Self-Hosted Runners

$(@($report.audit_sections.runners.findings | ForEach-Object { "- [$($_.severity.ToUpper())] $($_.title): $($_.description)" }) -join "`n")

Found $($report.audit_sections.runners.runner_profiles.Count) runner profiles.

## Installed Apps

Found $($report.audit_sections.apps_sdks.app_inventory.Count) installed apps.

---

Report generated on $($report.audit_timestamp)
"@
}

if ($OutputPath) {
    Set-Content -Path $OutputPath -Value $output
    Write-AuditLog "Report written to: $OutputPath"
}
else {
    Write-Host $output
}

exit 0

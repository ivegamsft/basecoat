param(
    [ValidateSet('markdown', 'json')]
    [string]$OutputFormat = 'markdown',
    [string]$OutputPath,
    [switch]$FailOnMismatch
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$workflowDir = Join-Path $repoRoot '.github\workflows'
if (-not (Test-Path $workflowDir)) {
    throw "Workflow directory not found: $workflowDir"
}

function Get-WorkflowJobBlocks {
    param(
        [string]$WorkflowPath
    )

    $lines = Get-Content $WorkflowPath
    $jobsStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*jobs:\s*$') {
            $jobsStart = $i
            break
        }
    }

    if ($jobsStart -lt 0) {
        return @()
    }

    $jobBlocks = @()
    $currentJobKey = $null
    $currentStart = -1

    for ($i = $jobsStart + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '^[A-Za-z0-9_-]+:\s*$') {
            break
        }

        if ($line -match '^\s{2}([A-Za-z0-9_-]+):\s*$') {
            if ($currentJobKey) {
                $jobBlocks += [pscustomobject]@{
                    JobKey = $currentJobKey
                    Start  = $currentStart
                    End    = $i - 1
                }
            }
            $currentJobKey = $matches[1]
            $currentStart = $i
        }
    }

    if ($currentJobKey) {
        $jobBlocks += [pscustomobject]@{
            JobKey = $currentJobKey
            Start  = $currentStart
            End    = $lines.Count - 1
        }
    }

    foreach ($job in $jobBlocks) {
        $job | Add-Member -NotePropertyName Content -NotePropertyValue (($lines[$job.Start..$job.End] -join "`n"))
    }

    return $jobBlocks
}

function Get-RunsOnRaw {
    param(
        [string]$JobContent
    )

    $lines = $JobContent -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s{4}runs-on:\s*(.*)$') {
            $inline = $matches[1].Trim()
            $block = @($inline)
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^\s{4}[A-Za-z0-9_-]+:\s*') {
                    break
                }
                if ($lines[$j] -match '^\s{2}[A-Za-z0-9_-]+:\s*$') {
                    break
                }
                if ($lines[$j] -match '^\s{6,}') {
                    $block += $lines[$j].Trim()
                    continue
                }
                if ($lines[$j].Trim().Length -eq 0) {
                    continue
                }
                break
            }

            return ($block -join ' ').Trim()
        }
    }

    return ''
}

function Get-ActualRunnerClass {
    param(
        [string]$RunsOnRaw,
        [string]$JobContent
    )

    if ([string]::IsNullOrWhiteSpace($RunsOnRaw)) {
        if ($JobContent -match '(?m)^\s{4}uses:\s*[^\r\n]+') {
            return 'reusable-workflow'
        }
        return 'missing-runs-on'
    }
    if ($RunsOnRaw -match 'matrix\.os') { return 'github-hosted-matrix' }
    if ($RunsOnRaw -match 'vars\.RUNNER_DEPLOY') { return 'configurable-deploy' }
    if ($RunsOnRaw -match 'self-hosted' -or $RunsOnRaw -match 'group:') { return 'self-hosted-linux' }
    if ($RunsOnRaw -match 'windows-latest') { return 'github-hosted-windows' }
    if ($RunsOnRaw -match 'macos') { return 'github-hosted-macos' }
    if ($RunsOnRaw -match 'ubuntu') { return 'github-hosted-linux' }
    return 'unknown'
}

function Get-RequiredCapabilities {
    param(
        [string]$WorkflowName,
        [string]$JobName,
        [string]$JobContent
    )

    $caps = New-Object System.Collections.Generic.HashSet[string]
    [void]$caps.Add('public-internet')

    $identityHints = @(
        'id-token:\s*write',
        'azure/login',
        '\baz\b',
        'azure'
    )
    foreach ($hint in $identityHints) {
        if ($JobContent -match $hint) {
            [void]$caps.Add('managed-identity')
        }
    }

    $deployWorkflowAllowList = @(
        'close-production-issues.yml',
        'docs-production.yml',
        'extension-deploy.yml',
        'mcp-deploy.yml',
        'portal-deploy.yml',
        'publish-to-production.yml',
        'release.yml'
    )

    $deployJobAllowList = @(
        'deploy',
        'build-push',
        'release'
    )

    if ($deployWorkflowAllowList -contains $WorkflowName.ToLowerInvariant() -or
        $deployJobAllowList -contains $JobName.ToLowerInvariant()) {
        [void]$caps.Add('deployment-credentials')
        [void]$caps.Add('private-network')
    }

    if ($WorkflowName.ToLowerInvariant() -eq 'release.yml') {
        [void]$caps.Add('deployment-credentials')
        [void]$caps.Add('private-network')
    }

    if ($JobContent -match 'environment:\s*production') {
        [void]$caps.Add('deployment-credentials')
        [void]$caps.Add('private-network')
    }

    if ($JobContent -match 'uses:\s*[^\s]+/\.github/workflows/') {
        [void]$caps.Add('delegated-runner')
    }

    if ($JobContent -match '(?m)^\s{4}uses:\s*[^\r\n]+') {
        [void]$caps.Add('delegated-runner')
    }

    if ($JobContent -match 'permissions:\s*[\r\n]+\s+contents:\s*read' -and
        $JobContent -notmatch 'id-token:\s*write' -and
        $JobContent -notmatch 'environment:\s*production') {
        [void]$caps.Add('public-ci')
    }

    if ($JobContent -match 'self-hosted' -or $JobContent -match 'group:\s*') {
        [void]$caps.Add('private-network')
    }

    if ($JobContent -match 'windows-latest') {
        [void]$caps.Add('windows-runtime')
    }

    if ($JobContent -match 'macos') {
        [void]$caps.Add('macos-runtime')
    }

    if ($JobContent -match 'pull_request_target') {
        [void]$caps.Add('untrusted-fork-safe')
    }

    if ($JobContent -match '(?s)matrix:.*ubuntu-latest' -and $JobContent -match '(?s)matrix:.*windows-latest') {
        [void]$caps.Add('multi-os-matrix')
    }

    return @($caps | Sort-Object)
}

function Get-RecommendedRunnerClass {
    param(
        [string[]]$Capabilities
    )

    if ($Capabilities -contains 'delegated-runner') { return 'reusable-workflow' }
    if ($Capabilities -contains 'multi-os-matrix') { return 'github-hosted-matrix' }
    if ($Capabilities -contains 'windows-runtime') { return 'github-hosted-windows' }
    if ($Capabilities -contains 'macos-runtime') { return 'github-hosted-macos' }
    if ($Capabilities -contains 'private-network' -or
        $Capabilities -contains 'managed-identity' -or
        $Capabilities -contains 'deployment-credentials') {
        return 'self-hosted-linux'
    }
    return 'github-hosted-linux'
}

function Get-AssignmentStatus {
    param(
        [string]$ActualRunnerClass,
        [string]$RecommendedRunnerClass
    )

    if ($ActualRunnerClass -eq 'reusable-workflow' -and $RecommendedRunnerClass -eq 'reusable-workflow') { return 'aligned' }
    if ($ActualRunnerClass -eq $RecommendedRunnerClass) { return 'aligned' }
    if ($ActualRunnerClass -eq 'configurable-deploy' -and $RecommendedRunnerClass -eq 'self-hosted-linux') { return 'conditional' }
    return 'mismatch'
}

function Escape-MarkdownCell {
    param(
        [string]$Value
    )

    if ($null -eq $Value) { return '' }
    return ($Value -replace '\|', '\|')
}

$workflowFiles = Get-ChildItem $workflowDir -Filter '*.yml' -File | Where-Object { $_.Name -notmatch '\.lock\.yml$' -and $_.Name -ne 'README.md' } | Sort-Object Name
$rows = @()

foreach ($workflow in $workflowFiles) {
    $jobBlocks = Get-WorkflowJobBlocks -WorkflowPath $workflow.FullName
    foreach ($job in $jobBlocks) {
        $runsOnRaw = Get-RunsOnRaw -JobContent $job.Content
        $actualRunnerClass = Get-ActualRunnerClass -RunsOnRaw $runsOnRaw -JobContent $job.Content
        $requiredCaps = Get-RequiredCapabilities -WorkflowName $workflow.Name -JobName $job.JobKey -JobContent $job.Content
        $recommendedRunnerClass = Get-RecommendedRunnerClass -Capabilities $requiredCaps
        $status = Get-AssignmentStatus -ActualRunnerClass $actualRunnerClass -RecommendedRunnerClass $recommendedRunnerClass

        $rows += [pscustomobject]@{
            Workflow               = $workflow.Name
            Job                    = $job.JobKey
            RequiredCapabilities   = ($requiredCaps -join ', ')
            RecommendedRunnerClass = $recommendedRunnerClass
            ActualRunnerClass      = $actualRunnerClass
            RunsOn                 = if ($runsOnRaw) { $runsOnRaw } else { '(missing)' }
            Status                 = $status
        }
    }
}

$mismatches = @($rows | Where-Object { $_.Status -eq 'mismatch' })
$conditionals = @($rows | Where-Object { $_.Status -eq 'conditional' })
$unclassified = @($rows | Where-Object { $_.ActualRunnerClass -in @('unknown', 'missing-runs-on') })

$summary = [pscustomobject]@{
    total_workflows    = $workflowFiles.Count
    total_jobs         = $rows.Count
    mismatches         = $mismatches.Count
    conditional_routes = $conditionals.Count
    unclassified_jobs  = $unclassified.Count
}

if ($OutputFormat -eq 'json') {
    $result = [pscustomobject]@{
        summary = $summary
        jobs    = $rows
    } | ConvertTo-Json -Depth 5
}
else {
    $lines = @()
    $lines += '# Workflow Runner Capability Audit'
    $lines += ''
    $lines += "| Metric | Value |"
    $lines += "|---|---|"
    $lines += "| Workflows scanned | $($summary.total_workflows) |"
    $lines += "| Jobs classified | $($summary.total_jobs) |"
    $lines += "| Mismatches | $($summary.mismatches) |"
    $lines += "| Conditional routes | $($summary.conditional_routes) |"
    $lines += "| Unclassified jobs | $($summary.unclassified_jobs) |"
    $lines += ''
    $lines += "| Workflow | Job | Required capabilities | Recommended runner class | Actual runner class | Status |"
    $lines += "|---|---|---|---|---|---|"
    foreach ($row in $rows) {
        $lines += "| $(Escape-MarkdownCell $row.Workflow) | $(Escape-MarkdownCell $row.Job) | $(Escape-MarkdownCell $row.RequiredCapabilities) | $(Escape-MarkdownCell $row.RecommendedRunnerClass) | $(Escape-MarkdownCell $row.ActualRunnerClass) | $(Escape-MarkdownCell $row.Status) |"
    }

    if ($mismatches.Count -gt 0) {
        $lines += ''
        $lines += '## Mismatch Details'
        $lines += ''
        $lines += "| Workflow | Job | Required capabilities | Recommended runner class | Actual runner class | runs-on |"
        $lines += "|---|---|---|---|---|---|"
        foreach ($row in $mismatches) {
            $lines += "| $(Escape-MarkdownCell $row.Workflow) | $(Escape-MarkdownCell $row.Job) | $(Escape-MarkdownCell $row.RequiredCapabilities) | $(Escape-MarkdownCell $row.RecommendedRunnerClass) | $(Escape-MarkdownCell $row.ActualRunnerClass) | $(Escape-MarkdownCell $row.RunsOn) |"
        }
    }

    $result = $lines -join "`n"
}

if ($OutputPath) {
    Set-Content -Path $OutputPath -Value $result
}
else {
    Write-Host $result
}

if ($FailOnMismatch -and ($summary.mismatches -gt 0 -or $summary.unclassified_jobs -gt 0)) {
    throw "Runner capability audit failed with $($summary.mismatches) mismatch(es) and $($summary.unclassified_jobs) unclassified job(s)."
}

exit 0

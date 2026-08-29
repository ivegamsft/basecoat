[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$validatorPath = Join-Path $repoRoot "scripts\validate-skill-workflow-dependencies.ps1"
$installerPath = Join-Path $repoRoot "scripts\configure-downstream-workflows.ps1"
$managedWorkflowsDir = Join-Path $repoRoot ".github\base-coat\workflows"
$knownGapsPath = Join-Path $repoRoot "scripts\known-workflow-dependency-gaps.json"

foreach ($path in @($validatorPath, $installerPath, $managedWorkflowsDir, $knownGapsPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing required distribution-validation asset: $path"
    }
}

# Regression for #2919: ship-it's SKILL.md promises three executable
# workflows. Each must now be distributable to a downstream consumer,
# without relying on the known-gaps allowlist.
$knownGaps = Get-Content -Raw -Path $knownGapsPath | ConvertFrom-Json
$knownGapNames = @($knownGaps | ForEach-Object { $_.workflow })

$shipItWorkflows = @(
    'ship-it-intent-dispatch.yml',
    'ship-it-build-guard.yml',
    'ship-it-release-gate.yml'
)

$installer = Get-Content -Raw -Path $installerPath
foreach ($workflowName in $shipItWorkflows) {
    if ($knownGapNames -contains $workflowName) {
        throw "$workflowName must not be listed in known-workflow-dependency-gaps.json; it is expected to be fully distributable."
    }

    $managedPath = Join-Path $managedWorkflowsDir $workflowName
    if (-not (Test-Path $managedPath)) {
        throw "ship-it workflow dependency $workflowName must be copied into .github/base-coat/workflows so downstream consumers can install it."
    }

    if ($installer -notmatch [regex]::Escape("Source = '$workflowName'")) {
        throw "ship-it workflow dependency $workflowName must be registered as a Source entry in scripts/configure-downstream-workflows.ps1."
    }
}

# Regression: a bare (non-`.github/workflows/`-prefixed) code-span reference
# to a workflow that does not exist anywhere must still be flagged, even
# though it cannot be found in any "known workflow names on disk" universe.
# This is the exact silent-pass class of bug the validator must not
# reintroduce (a SKILL.md/agent.md promising a workflow that was never
# created, renamed away, or typo'd would otherwise pass validation).
$tempSkillsRoot = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-missing-workflow-sim-$([guid]::NewGuid().ToString('N'))"
try {
    $tempSkillDir = Join-Path $tempSkillsRoot "skills\bare-missing-workflow-probe"
    New-Item -ItemType Directory -Force -Path $tempSkillDir | Out-Null
    Set-Content -Path (Join-Path $tempSkillDir "SKILL.md") -Value @'
# Bare Missing Workflow Probe

Dispatch `missing-control-plane.yml` to coordinate the release.
'@ -Encoding UTF8

    Push-Location $repoRoot
    try {
        $probeSkillDir = Join-Path $repoRoot "skills\__bare-missing-workflow-probe__"
        if (Test-Path $probeSkillDir) {
            throw "Probe skill directory unexpectedly already exists: $probeSkillDir"
        }
        Copy-Item -Path $tempSkillDir -Destination $probeSkillDir -Recurse -Force
        try {
            $probeLogPath = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-missing-workflow-probe-$([guid]::NewGuid().ToString('N')).log"
            try {
                & pwsh -NoProfile -File $validatorPath *> $probeLogPath
                $probeExitCode = $LASTEXITCODE
                $probeText = Get-Content -Raw -Path $probeLogPath
            } finally {
                Remove-Item -Path $probeLogPath -Force -ErrorAction SilentlyContinue
            }
            if ($probeExitCode -eq 0 -or $probeText -notmatch [regex]::Escape("'missing-control-plane.yml'")) {
                throw "Validator did not flag a bare reference to a nonexistent workflow (missing-control-plane.yml). Output: $probeText"
            }
        } finally {
            Remove-Item -Path $probeSkillDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } finally {
        Pop-Location
    }
} finally {
    if (Test-Path $tempSkillsRoot) {
        Remove-Item -Path $tempSkillsRoot -Recurse -Force
    }
}

# Regression for #2919 review round 4: a workflow reference living only in a
# skill's references/*.md doc (never mentioned in SKILL.md itself) must
# still be caught. Scanning SKILL.md alone previously let such references
# bypass this validator entirely (e.g. issue-triage's
# references/metadata-contract.md -> issue-metadata-hygiene.yml, and
# ship-it/dispatch-intent.ps1's stale sprint-closeout-branch-audit.yml
# reference).
$tempRefProbeRoot = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-reference-doc-probe-$([guid]::NewGuid().ToString('N'))"
try {
    $tempRefSkillDir = Join-Path $tempRefProbeRoot "skills\reference-doc-probe"
    $tempRefDocsDir = Join-Path $tempRefSkillDir "references"
    New-Item -ItemType Directory -Force -Path $tempRefDocsDir | Out-Null
    Set-Content -Path (Join-Path $tempRefSkillDir "SKILL.md") -Value @'
# Reference Doc Probe

See references/contract.md for details.
'@ -Encoding UTF8
    Set-Content -Path (Join-Path $tempRefDocsDir "contract.md") -Value @'
# Contract

Dispatch `missing-reference-doc-workflow.yml` to coordinate cleanup.
'@ -Encoding UTF8

    Push-Location $repoRoot
    try {
        $probeSkillDir = Join-Path $repoRoot "skills\__reference-doc-probe__"
        if (Test-Path $probeSkillDir) {
            throw "Probe skill directory unexpectedly already exists: $probeSkillDir"
        }
        Copy-Item -Path $tempRefSkillDir -Destination $probeSkillDir -Recurse -Force
        try {
            $probeLogPath = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-reference-doc-probe-$([guid]::NewGuid().ToString('N')).log"
            try {
                & pwsh -NoProfile -File $validatorPath *> $probeLogPath
                $probeExitCode = $LASTEXITCODE
                $probeText = Get-Content -Raw -Path $probeLogPath
            } finally {
                Remove-Item -Path $probeLogPath -Force -ErrorAction SilentlyContinue
            }
            if ($probeExitCode -eq 0 -or $probeText -notmatch [regex]::Escape("'missing-reference-doc-workflow.yml'")) {
                throw "Validator did not flag a workflow reference that lives only in a skill's references/*.md doc (missing-reference-doc-workflow.yml). Output: $probeText"
            }
        } finally {
            Remove-Item -Path $probeSkillDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } finally {
        Pop-Location
    }
} finally {
    if (Test-Path $tempRefProbeRoot) {
        Remove-Item -Path $tempRefProbeRoot -Recurse -Force
    }
}

# Full-repo run: every public skill's referenced workflow must resolve to an
# installable downstream dependency (or be explicitly, narrowly allowlisted).
& $validatorPath

# Simulated downstream install: copy this repo's managed distribution source
# (as sync.ps1/sync.sh would land it in a consumer repo) into a temp
# consumer, run the installer against it, and confirm every runtime script
# path the installed workflows invoke actually resolves on disk. This is the
# regression #2919 requires: a passing dependency-closure check that never
# actually simulates installation would miss workflows that reference
# runtime scripts absent from the managed payload (as ship-it's did before
# this fix).
$tempConsumer = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-downstream-sim-$([guid]::NewGuid().ToString('N'))"
try {
    $consumerManagedWorkflows = Join-Path $tempConsumer ".github\base-coat\workflows"
    $consumerManagedScripts = Join-Path $tempConsumer ".github\base-coat\scripts"
    $consumerWorkflows = Join-Path $tempConsumer ".github\workflows"
    New-Item -ItemType Directory -Force -Path $consumerManagedWorkflows | Out-Null
    New-Item -ItemType Directory -Force -Path $consumerManagedScripts | Out-Null
    New-Item -ItemType Directory -Force -Path $consumerWorkflows | Out-Null

    Copy-Item -Path (Join-Path $managedWorkflowsDir '*') -Destination $consumerManagedWorkflows -Recurse -Force
    $managedScriptsSource = Join-Path $repoRoot ".github\base-coat\scripts"
    Copy-Item -Path (Join-Path $managedScriptsSource '*') -Destination $consumerManagedScripts -Recurse -Force

    $simulatedWorkflows = $shipItWorkflows + @('project-rules-drift-audit.yml', 'adoption-metrics.yml')
    & $installerPath -SourceDir $consumerManagedWorkflows -DestinationDir $consumerWorkflows -Workflow $simulatedWorkflows | Out-Null

    foreach ($workflowName in $simulatedWorkflows) {
        $installedPath = Join-Path $consumerWorkflows $workflowName
        if (-not (Test-Path $installedPath)) {
            throw "Simulated downstream install did not produce $workflowName in .github/workflows."
        }

        $installedContent = Get-Content -Raw -Path $installedPath
        $scriptRefs = [regex]::Matches($installedContent, '\.(?:\\|/)?github(?:\\|/)base-coat(?:\\|/)scripts(?:\\|/)[\w.\-\\/]+\.(?:ps1|py|json)')
        if ($scriptRefs.Count -eq 0) {
            continue
        }

        foreach ($refMatch in $scriptRefs) {
            $relative = $refMatch.Value -replace '^\.[\\/]', '' -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
            $resolvedScriptPath = Join-Path $tempConsumer $relative
            if (-not (Test-Path $resolvedScriptPath)) {
                throw "Installed workflow $workflowName references runtime dependency '$($refMatch.Value)' that is missing from the simulated downstream install (expected at $resolvedScriptPath)."
            }
        }
    }
}
finally {
    if (Test-Path $tempConsumer) {
        Remove-Item -Path $tempConsumer -Recurse -Force
    }
}

Write-Host "PASS: ship-it workflow dependencies are distributable and the full skill dependency closure validates."

$ErrorActionPreference = 'Stop'

$targetDir = if ($env:BASECOAT_TARGET_DIR) { $env:BASECOAT_TARGET_DIR } else { '.github/base-coat' }
$knownBadRefRedirects = @{
    'v3.30.4' = 'v3.30.5'
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is required'
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw 'Run this inside a git repository'
}

# Resolve the upstream source repo and ref.
# Precedence: BASECOAT_REPO/BASECOAT_REF env vars > repo-root .basecoat.yml > built-in default.
function Get-BasecoatYmlValue {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $config = Join-Path $RepoRoot '.basecoat.yml'
    if (-not (Test-Path -LiteralPath $config)) { return $null }

    foreach ($line in Get-Content -LiteralPath $config) {
        # Match only top-level (unindented, non-comment) "key: value" entries.
        if ($line -match "^$([regex]::Escape($Key)):\s*(.*)$") {
            # A value that is empty or begins with '#' is a comment-only entry (null).
            $value = ($Matches[1] -replace '^#.*$', '' -replace '\s+#.*$', '').Trim()
            # Only strip quotes that form a matching surrounding pair (a lone
            # trailing/leading quote is a legitimate part of a Git ref name).
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $Matches[1]
            }
            return $value
        }
    }

    return $null
}

function Get-RedactedRepoUrl {
    param([string]$Url)

    if (-not $Url) { return $Url }
    # Strip any "user[:password]@" userinfo and any "?query"/"#fragment" (which may
    # carry a token) so credential-bearing clone URLs are never logged. Only the
    # display value is sanitized; git clone still receives the original URL.
    # Capture the scheme rather than using a lookbehind for broad regex portability.
    # Match case-insensitively since URI schemes are case-insensitive.
    $display = $Url -replace '(?i)^(https?://)[^/@]*@', '$1'
    return ($display -replace '[?#].*$', '')
}

$sourceRepo = $env:BASECOAT_REPO
$sourceRepoOrigin = 'env'
if (-not $sourceRepo) {
    $sourceRepo = Get-BasecoatYmlValue -Key 'source' -RepoRoot $repoRoot
    if ($sourceRepo) {
        $sourceRepoOrigin = '.basecoat.yml'
    }
    else {
        $sourceRepo = 'https://github.com/YOUR-ORG/basecoat.git'
        $sourceRepoOrigin = 'default'
    }
}

$sourceRef = $env:BASECOAT_REF
$sourceRefOrigin = 'env'
if (-not $sourceRef) {
    $sourceRef = Get-BasecoatYmlValue -Key 'ref' -RepoRoot $repoRoot
    if ($sourceRef) {
        $sourceRefOrigin = '.basecoat.yml'
    }
    else {
        $sourceRef = 'main'
        $sourceRefOrigin = 'default'
    }
}

if ($knownBadRefRedirects.ContainsKey($sourceRef)) {
    $requestedRef = $sourceRef
    $sourceRef = $knownBadRefRedirects[$requestedRef]
    $sourceRefOrigin = 'redirect'
    Write-Warning "Requested ref '$requestedRef' is a known-bad release tag (version drift). Auto-upgrading sync source to '$sourceRef'. Update your .basecoat.yml pin to '$sourceRef' or newer."
}

Write-Host "Resolved BaseCoat source '$(Get-RedactedRepoUrl $sourceRepo)' (from $sourceRepoOrigin), ref '$sourceRef' (from $sourceRefOrigin)"

$allowedDocsTopLevelEntries = @('reference', 'guides', 'agents', 'diagrams')
$supportedAgentFrontmatterKeys = @('name', 'description', 'tools', 'mcp-servers')

function Convert-AgentToCliCompatibleContent {
    param(
        [string]$Content
    )

    if ($Content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---\s*\r?\n?(.*)$') {
        return $Content
    }

    $frontmatter = $Matches[1]
    $body = $Matches[2]
    $frontLines = $frontmatter -split "`r?`n"
    $chunks = [System.Collections.Generic.List[object]]::new()
    $currentChunk = $null

    foreach ($line in $frontLines) {
        if ($line -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
            if ($null -ne $currentChunk) {
                $chunks.Add($currentChunk)
            }
            $currentChunk = [pscustomobject]@{
                Key   = $Matches[1]
                Value = $Matches[2]
                Lines = [System.Collections.Generic.List[string]]::new()
            }
            $currentChunk.Lines.Add($line)
        }
        elseif ($null -ne $currentChunk) {
            $currentChunk.Lines.Add($line)
        }
    }
    if ($null -ne $currentChunk) {
        $chunks.Add($currentChunk)
    }

    $selected = [System.Collections.Generic.List[object]]::new()
    $toolsChunk = $null
    $allowedToolsChunk = $null

    foreach ($chunk in $chunks) {
        if ($chunk.Key -eq 'tools') { $toolsChunk = $chunk }
        if ($chunk.Key -eq 'allowed-tools') { $allowedToolsChunk = $chunk }
        if ($chunk.Key -in $supportedAgentFrontmatterKeys) {
            $selected.Add($chunk)
        }
    }

    if (-not $toolsChunk -and $allowedToolsChunk) {
        $remapped = [pscustomobject]@{
            Key   = 'tools'
            Value = $allowedToolsChunk.Value
            Lines = [System.Collections.Generic.List[string]]::new()
        }
        foreach ($line in $allowedToolsChunk.Lines) {
            if ($line -match '^allowed-tools:') {
                $remapped.Lines.Add(($line -replace '^allowed-tools:', 'tools:'))
            }
            else {
                $remapped.Lines.Add($line)
            }
        }
        $selected.Add($remapped)
    }

    $ordered = @()
    foreach ($key in @('name', 'description', 'tools', 'mcp-servers')) {
        $match = $selected | Where-Object { $_.Key -eq $key } | Select-Object -First 1
        if ($match) { $ordered += $match }
    }

    $newFrontmatterLines = [System.Collections.Generic.List[string]]::new()
    foreach ($chunk in $ordered) {
        foreach ($line in $chunk.Lines) {
            $newFrontmatterLines.Add($line)
        }
    }
    $newFrontmatter = ($newFrontmatterLines -join "`n").TrimEnd()

    return "---`n$newFrontmatter`n---`n`n$body"
}

function Remove-PathWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$MaxAttempts = 5,
        [int]$DelayMilliseconds = 200
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return
        }
        catch {
            if (-not (Test-Path -LiteralPath $Path)) {
                return
            }
            if ($attempt -eq $MaxAttempts) {
                throw "Failed to remove temporary path '$Path' after $MaxAttempts attempts: $($_.Exception.Message)"
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Assert-MinimalDocsScope {
    param(
        [string]$DocsPath
    )

    if (-not (Test-Path $DocsPath)) {
        throw "Docs scope validation failed: '$DocsPath' does not exist"
    }

    $topLevelEntries = Get-ChildItem -Path $DocsPath -Force
    $unexpectedTopLevel = $topLevelEntries | Where-Object { $_.Name -notin $allowedDocsTopLevelEntries }
    if ($unexpectedTopLevel.Count -gt 0) {
        $names = ($unexpectedTopLevel | ForEach-Object { $_.Name } | Sort-Object) -join ', '
        throw "Docs scope validation failed: unexpected docs entries synced: $names"
    }

    $agentsDocsPath = Join-Path $DocsPath 'agents'
    if (Test-Path $agentsDocsPath) {
        $unexpectedAgentDocs = Get-ChildItem -Path $agentsDocsPath -Force | Where-Object {
            $_.PSIsContainer -or $_.Name -ne 'AGENTS.md'
        }
        if ($unexpectedAgentDocs.Count -gt 0) {
            $names = ($unexpectedAgentDocs | ForEach-Object { $_.Name } | Sort-Object) -join ', '
            throw "Docs scope validation failed: docs/agents must only contain AGENTS.md, found: $names"
        }
    }
}

function Assert-SafeWorkflowDirectory {
    param(
        [string]$WorkflowsPath
    )

    if (-not (Test-Path $WorkflowsPath)) {
        return
    }

    $workflowFiles = Get-ChildItem -Path $WorkflowsPath -File | Where-Object { $_.Extension -in @('.yml', '.yaml') } | Sort-Object -Property Name
    if ($workflowFiles.Count -eq 0) {
        return
    }

    $supportsYamlParsing = $null -ne (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)
    $issues = [System.Collections.Generic.List[string]]::new()

    foreach ($workflowFile in $workflowFiles) {
        $content = Get-Content -Path $workflowFile.FullName -Raw

        if ($supportsYamlParsing) {
            try {
                $null = $content | ConvertFrom-Yaml -ErrorAction Stop
            }
            catch {
                $issues.Add("$($workflowFile.Name): malformed YAML ($($_.Exception.Message))")
                continue
            }
        }

        $lineNumber = 0
        $insideLiteralBlock = $false
        $literalBlockIndent = -1
        foreach ($line in ($content -split "`r?`n")) {
            $lineNumber++

            if ($line -match '^(\s*)') {
                $lineIndent = $Matches[1].Length
            } else {
                $lineIndent = 0
            }
            $trimmedLine = $line.Trim()

            if ($insideLiteralBlock) {
                if ($trimmedLine.Length -eq 0 -or $lineIndent -gt $literalBlockIndent) {
                    continue
                }

                $insideLiteralBlock = $false
                $literalBlockIndent = -1
            }

            if ($line -match '^\s*(run|script):\s*[|>][-+]?\s*(#.*)?$') {
                $insideLiteralBlock = $true
                $literalBlockIndent = $lineIndent
                continue
            }

            if ($line -notmatch '^\s*uses:\s*["'']?(?<uses>[^\s"''#]+)') {
                continue
            }

            $usesRef = $Matches['uses']
            if ($usesRef -like './.github/base-coat/workflows/*') {
                $issues.Add("$($workflowFile.Name):$lineNumber invalid reusable workflow reference '$usesRef' (must use ./.github/workflows/<file>.yml for local reusable workflows)")
                continue
            }

            if (($usesRef -like './*.yml' -or $usesRef -like './*.yaml') -and $usesRef -notlike './.github/workflows/*') {
                $issues.Add("$($workflowFile.Name):$lineNumber invalid local workflow path '$usesRef' (local reusable workflows must be under ./.github/workflows/)")
            }
        }
    }

    if ($issues.Count -gt 0) {
        $details = ($issues | ForEach-Object { " - $_" }) -join "`n"
        throw "Workflow validation failed before sync. Invalid workflow definitions detected:`n$details"
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$sourcePath = Join-Path $tempRoot 'source'

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    git clone --depth 1 --branch $sourceRef $sourceRepo $sourcePath | Out-Null

    $fullTargetDir = Join-Path $repoRoot $targetDir
    New-Item -ItemType Directory -Force -Path $fullTargetDir | Out-Null

    foreach ($item in @('README.md', 'CHANGELOG.md', 'version.json', 'asset-manifest.json', 'instructions', 'skills', 'prompts', 'agents', 'templates')) {
        $destination = Join-Path $fullTargetDir $item
        if (Test-Path $destination) {
            Remove-Item -Path $destination -Recurse -Force
        }
        $sourceItem = Join-Path $sourcePath $item
        if (Test-Path $sourceItem) {
            Copy-Item -Path $sourceItem -Destination $destination -Recurse -Force
        }
    }

    # Copy workflows from .github/base-coat/workflows/
    $workflowsSource = Join-Path $sourcePath '.github' 'base-coat' 'workflows'
    $workflowsDest = Join-Path $fullTargetDir 'workflows'
    if (Test-Path $workflowsSource) {
        Assert-SafeWorkflowDirectory -WorkflowsPath $workflowsSource
        if (Test-Path $workflowsDest) {
            Remove-Item -Path $workflowsDest -Recurse -Force
        }
        Copy-Item -Path $workflowsSource -Destination $workflowsDest -Recurse -Force
    }

    # Copy runtime scripts and installed-payload validators.
    $runtimeScriptsSource = Join-Path $sourcePath '.github' 'base-coat' 'scripts'
    $runtimeScriptsDest = Join-Path $fullTargetDir 'scripts'
    if (Test-Path $runtimeScriptsDest) {
        Remove-Item -Path $runtimeScriptsDest -Recurse -Force
    }
    New-Item -ItemType Directory -Path $runtimeScriptsDest -Force | Out-Null
    if (Test-Path $runtimeScriptsSource) {
        Copy-Item -Path (Join-Path $runtimeScriptsSource '*') -Destination $runtimeScriptsDest -Recurse -Force
    }
    foreach ($validator in @(
            'validate-basecoat.ps1',
            'validate-basecoat.sh',
            'validate-workflow-action-pins.ps1',
            'validate-workflow-action-pins.py'
        )) {
        $validatorSource = Join-Path $sourcePath "scripts/$validator"
        if (Test-Path $validatorSource -PathType Leaf) {
            Copy-Item -Path $validatorSource -Destination (Join-Path $runtimeScriptsDest $validator) -Force
        }
    }

    # Copy only basic documentation (not full docs tree)
    $docsDest = Join-Path $fullTargetDir 'docs'
    if (Test-Path $docsDest) {
        Remove-Item -Path $docsDest -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $docsDest | Out-Null

    foreach ($docSubdir in @('reference', 'guides', 'diagrams')) {
        $src = Join-Path $sourcePath "docs/$docSubdir"
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $docsDest $docSubdir) -Recurse -Force
        }
    }

    $agentsCatalog = Join-Path $sourcePath 'docs/agents/AGENTS.md'
    if (Test-Path $agentsCatalog) {
        $agentsDocsDest = Join-Path $docsDest 'agents'
        New-Item -ItemType Directory -Force -Path $agentsDocsDest | Out-Null
        Copy-Item -Path $agentsCatalog -Destination (Join-Path $agentsDocsDest 'AGENTS.md') -Force
    }

    Assert-MinimalDocsScope -DocsPath $docsDest

    # INVENTORY.md moved to docs/reference/ in v3.11.0 — copy from new location to target root for backwards compat
    # Accepts both INVENTORY.md and inventory.md (Phase 3+4 rename to lowercase)
    $inventorySrc = if (Test-Path (Join-Path $sourcePath 'docs/reference/INVENTORY.md')) {
        Join-Path $sourcePath 'docs/reference/INVENTORY.md'
    } elseif (Test-Path (Join-Path $sourcePath 'docs/reference/inventory.md')) {
        Join-Path $sourcePath 'docs/reference/inventory.md'
    } else { $null }
    if ($inventorySrc) {
        Copy-Item -Path $inventorySrc -Destination (Join-Path $fullTargetDir 'INVENTORY.md') -Force
    }

    # Remove agent taxonomy subdirs from staging — they contain only index
    # READMEs with relative links that break outside the source repo
    foreach ($taxDir in @('models', 'orchestrator', 'tasks', 'types')) {
        $taxPath = Join-Path $fullTargetDir "agents/$taxDir"
        if (Test-Path $taxPath) {
            Remove-Item -Path $taxPath -Recurse -Force
        }
    }

    # Remove eval metadata from synced agents to avoid leaking internal test files.
    $agentEvalFiles = Get-ChildItem -Path (Join-Path $fullTargetDir 'agents') -Filter '*.agent.eval.yaml' -File -ErrorAction SilentlyContinue
    if ($agentEvalFiles) {
        $agentEvalFiles | Remove-Item -Force
    }

    # Copy Copilot-discoverable directories to their standard paths
    # Only copy flat agent/instruction/prompt/skill files — not taxonomy subdirs
    $githubDir = Join-Path $repoRoot '.github'
    New-Item -ItemType Directory -Force -Path $githubDir | Out-Null
    foreach ($copilotDir in @('instructions', 'prompts', 'skills')) {
        $source = Join-Path $fullTargetDir $copilotDir
        $dest = Join-Path $githubDir $copilotDir
        if (Test-Path $source) {
            if (Test-Path $dest) {
                Remove-Item -Path $dest -Recurse -Force
            }
            Copy-Item -Path $source -Destination $dest -Recurse -Force
        }
    }

    # Also copy skills to .agents/skills/ for cross-client interop (Agent Skills spec)
    $skillsSource = Join-Path $fullTargetDir 'skills'
    $agentSkillsDest = Join-Path $repoRoot '.agents' 'skills'
    if (Test-Path $skillsSource) {
        New-Item -ItemType Directory -Force -Path $agentSkillsDest | Out-Null
        if (Test-Path $agentSkillsDest) {
            Remove-Item -Path $agentSkillsDest -Recurse -Force
        }
        Copy-Item -Path $skillsSource -Destination $agentSkillsDest -Recurse -Force
    }

    # Agents: copy only *.agent.md files (skip taxonomy subdirs like models/, tasks/, types/)
    $agentSource = Join-Path $fullTargetDir 'agents'
    $agentDest = Join-Path $githubDir 'agents'
    if (Test-Path $agentSource) {
        if (Test-Path $agentDest) {
            Remove-Item -Path $agentDest -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $agentDest | Out-Null
        Get-ChildItem -Path $agentSource -Filter '*.agent.md' | ForEach-Object {
            $raw = Get-Content -Path $_.FullName -Raw
            $sanitized = Convert-AgentToCliCompatibleContent -Content $raw
            Set-Content -Path (Join-Path $agentDest $_.Name) -Value $sanitized -Encoding UTF8
        }
    }

    # Seed release-notes template into downstream-customizable location.
    # Never overwrite local customizations.
    $managedReleaseTemplate = Join-Path $fullTargetDir 'templates/release-notes/default.md'
    $customReleaseTemplate = Join-Path $repoRoot '.github/release-notes/templates/default.md'
    if ((Test-Path $managedReleaseTemplate) -and -not (Test-Path $customReleaseTemplate)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $customReleaseTemplate) | Out-Null
        Copy-Item -Path $managedReleaseTemplate -Destination $customReleaseTemplate -Force
    }

    # Seed intake contract templates into downstream-customizable locations.
    # Never overwrite local customizations.
    $managedPrTemplate = Join-Path $fullTargetDir 'templates/intake/PULL_REQUEST_TEMPLATE.md'
    $customPrTemplate = Join-Path $repoRoot '.github/PULL_REQUEST_TEMPLATE.md'
    if ((Test-Path $managedPrTemplate) -and -not (Test-Path $customPrTemplate)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $customPrTemplate) | Out-Null
        Copy-Item -Path $managedPrTemplate -Destination $customPrTemplate -Force
    }

    $managedIssueTemplate = Join-Path $fullTargetDir 'templates/intake/issue.md'
    $customIssueTemplate = Join-Path $repoRoot '.github/ISSUE_TEMPLATE/issue.md'
    if ((Test-Path $managedIssueTemplate) -and -not (Test-Path $customIssueTemplate)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $customIssueTemplate) | Out-Null
        Copy-Item -Path $managedIssueTemplate -Destination $customIssueTemplate -Force
    }

    # Optional cleanup pass for stale managed files from prior versions.
    # Uses hash snapshoting to avoid deleting customized files.
    $cleanupScript = Join-Path $repoRoot 'scripts/cleanup-basecoat-upgrade.ps1'
    if (Test-Path $cleanupScript) {
        & $cleanupScript -TargetDir $targetDir -ProtectCustomized -SetArchiveReadOnly
    }

    if ($sourceRef -match '^v(?<version>\d+\.\d+\.\d+)$') {
        $expectedVersion = $Matches['version']
        $versionFile = Join-Path $fullTargetDir 'version.json'
        if (-not (Test-Path $versionFile)) {
            throw "BaseCoat ref/version provenance check failed: '$sourceRef' requires version.json but the file is missing."
        }

        $parsedVersion = (Get-Content -Path $versionFile -Raw | ConvertFrom-Json).version
        if (-not $parsedVersion) {
            throw "BaseCoat ref/version provenance check failed: '$versionFile' does not contain a version field."
        }

        if ($parsedVersion -ne $expectedVersion) {
            throw "BaseCoat ref/version provenance check failed: requested '$sourceRef' expects version '$expectedVersion' but synced payload reports '$parsedVersion'."
        }
    }

    Write-Host "Base Coat synced into $targetDir"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        try {
            Remove-PathWithRetry -Path $tempRoot
        }
        catch {
            Write-Warning "Cleanup warning: $($_.Exception.Message)"
        }
    }
}

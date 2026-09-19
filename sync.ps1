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
# Precedence: BASECOAT_REPO/BASECOAT_REF env vars > repo-root .basecoat.yml.
# A missing source repo fails fast rather than falling back to a placeholder URL.
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

function Get-BasecoatYmlMap {
    param(
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $result = @{}
    $config = Join-Path $RepoRoot '.basecoat.yml'
    if (-not (Test-Path -LiteralPath $config)) { return $result }

    $inSection = $false
    foreach ($line in Get-Content -LiteralPath $config) {
        if ($line -match '^\s*(#|$)') { continue }
        if ($line -match '^([A-Za-z0-9_-]+):\s*$') {
            $inSection = $Matches[1] -eq $Section
            continue
        }
        if ($inSection -and $line -match '^\s{2,}([^:]+):\s*(.+)$') {
            $key = $Matches[1].Trim().Trim('"', "'")
            $value = ($Matches[2] -replace '\s+#.*$', '').Trim().Trim('"', "'")
            $result[$key] = $value
            continue
        }
        if ($inSection -and $line -match '^\S') { break }
    }
    return $result
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

function Protect-SyncSensitiveText {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return $null }
    $text = [string]$Value
    $text = $text -replace '(?i)(https?://)[^/@\s]+@', '$1'
    $text = $text -replace '(?i)(https?://[^\s?#]+)[?#][^\s]*', '$1'
    $text = $text -replace '(?i)(AUTHORIZATION:\s*basic\s+)\S+', '${1}***'
    foreach ($secret in @($env:BASECOAT_UPDATE_TOKEN, $env:BASECOAT_FETCH_TOKEN, $env:GH_TOKEN, $env:GITHUB_TOKEN)) {
        if ($secret) { $text = $text.Replace($secret, '***') }
    }
    return $text
}

function Invoke-SyncGit {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = & git @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $safeArguments = @($Arguments | ForEach-Object { Protect-SyncSensitiveText $_ })
    $safeOutput = @($output | ForEach-Object { Protect-SyncSensitiveText $_ })
    if ($exitCode -ne 0) {
        throw "git $($safeArguments -join ' ') failed (exit $exitCode): $($safeOutput -join "`n")"
    }
    return $safeOutput
}

function Invoke-SyncGitWithAuthRetry {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$RepoUrl
    )

    try {
        return Invoke-SyncGit -Arguments $Arguments
    }
    catch {
        $token = $env:BASECOAT_FETCH_TOKEN
        $trustedAuthority = $env:BASECOAT_FETCH_HOST
        $uri = $null
        if (-not $token -or -not $trustedAuthority -or
            -not [uri]::TryCreate($RepoUrl, [System.UriKind]::Absolute, [ref]$uri) -or
            $uri.Scheme -ne 'https' -or
            -not $uri.Authority.Equals($trustedAuthority, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw
        }
        $authBytes = [Text.Encoding]::ASCII.GetBytes("x-access-token:$token")
        $authHeader = [Convert]::ToBase64String($authBytes)
        $authOrigin = "$($uri.Scheme)://$($uri.Authority)/"
        $authenticatedArguments = @(
            '-c', "http.$authOrigin.extraheader=AUTHORIZATION: basic $authHeader"
        ) + $Arguments
        return Invoke-SyncGit -Arguments $authenticatedArguments
    }
}

$sourceRepo = $env:BASECOAT_REPO
$sourceRepoOrigin = 'env'
if (-not $sourceRepo) {
    $sourceRepo = Get-BasecoatYmlValue -Key 'source' -RepoRoot $repoRoot
    if ($sourceRepo) {
        $sourceRepoOrigin = '.basecoat.yml'
    }
    else {
        throw "No BaseCoat source configured. Set 'source:' in .basecoat.yml or the BASECOAT_REPO env var."
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

$configuredRedirects = Get-BasecoatYmlMap -Section 'known_bad_releases' -RepoRoot $repoRoot
foreach ($entry in $configuredRedirects.GetEnumerator()) {
    $knownBadRefRedirects[$entry.Key] = $entry.Value
}

if ($knownBadRefRedirects.ContainsKey($sourceRef)) {
    $requestedRef = $sourceRef
    $sourceRef = $knownBadRefRedirects[$requestedRef]
    $sourceRefOrigin = 'redirect'
    Write-Warning "Requested ref '$requestedRef' is a known-bad release tag (version drift). Auto-upgrading sync source to '$sourceRef'. Update your .basecoat.yml pin to '$sourceRef' or newer."
}

$sourceMirror = $env:BASECOAT_MIRROR
$sourceMirrorOrigin = 'env'
if (-not $sourceMirror) {
    $sourceMirror = Get-BasecoatYmlValue -Key 'mirror' -RepoRoot $repoRoot
    $sourceMirrorOrigin = if ($sourceMirror) { '.basecoat.yml' } else { 'unset' }
}
$fetchRepo = if ($sourceMirror) { $sourceMirror } else { $sourceRepo }

Write-Host "Resolved BaseCoat source '$(Get-RedactedRepoUrl $sourceRepo)' (from $sourceRepoOrigin), ref '$sourceRef' (from $sourceRefOrigin)"
if ($sourceMirror) {
    Write-Host "Using corporate mirror '$(Get-RedactedRepoUrl $sourceMirror)' (from $sourceMirrorOrigin) for immutable fetches."
}

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
    if (@($unexpectedTopLevel).Count -gt 0) {
        $names = ($unexpectedTopLevel | ForEach-Object { $_.Name } | Sort-Object) -join ', '
        throw "Docs scope validation failed: unexpected docs entries synced: $names"
    }

    $agentsDocsPath = Join-Path $DocsPath 'agents'
    if (Test-Path $agentsDocsPath) {
        $unexpectedAgentDocs = Get-ChildItem -Path $agentsDocsPath -Force | Where-Object {
            $_.PSIsContainer -or $_.Name -ne 'AGENTS.md'
        }
        if (@($unexpectedAgentDocs).Count -gt 0) {
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

function Get-RepoRelativePath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $fullPath = (Resolve-Path -LiteralPath $Path).Path
    $fullRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $relative = $fullPath.Substring($fullRoot.Length).TrimStart('\', '/')
    return ($relative -replace '\\', '/')
}

function Get-CanonicalRealPath {
    <#
    .SYNOPSIS
      Resolves symbolic links / junctions on every existing path segment
      (not just the leaf), so a linked ancestor placed by a co-located
      overlay (foreign or otherwise) cannot silently redirect a write or
      delete outside the intended destination (#3415 follow-up hardening).
    #>
    param([Parameter(Mandatory)][string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetPathRoot($full)
    if ([string]::IsNullOrEmpty($root)) {
        $root = [string]([System.IO.Path]::DirectorySeparatorChar)
    }
    $remainder = $full.Substring($root.Length)
    $separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $segments = $remainder.Split($separators, [System.StringSplitOptions]::RemoveEmptyEntries)
    $accumulated = $root
    foreach ($segment in $segments) {
        $accumulated = Join-Path $accumulated $segment
        if (Test-Path -LiteralPath $accumulated) {
            $item = Get-Item -LiteralPath $accumulated -Force
            $linkTarget = $item.ResolveLinkTarget($true)
            if ($null -ne $linkTarget) {
                $accumulated = $linkTarget.FullName
            }
        }
    }
    return [System.IO.Path]::GetFullPath($accumulated)
}

function Test-PathWithinBoundary {
    <#
    .SYNOPSIS
      Returns $true only if canonical $Path (existing segments resolved
      through symlinks/junctions) is equal to or nested under canonical
      $BoundaryRoot. Used to enforce that overlay copies/deletes can never
      escape their intended destination root via a planted symlink.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$BoundaryRoot
    )

    $canonicalPath = Get-CanonicalRealPath -Path $Path
    $canonicalBoundary = (Get-CanonicalRealPath -Path $BoundaryRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar
    )
    $boundaryWithSeparator = $canonicalBoundary + [System.IO.Path]::DirectorySeparatorChar
    $comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
    return $canonicalPath.Equals($canonicalBoundary, $comparison) -or $canonicalPath.StartsWith($boundaryWithSeparator, $comparison)
}

function Copy-ManagedOverlayTree {
    <#
    .SYNOPSIS
      Copies a BaseCoat-managed directory into a shared Copilot-discoverable
      path (e.g. .github/skills) without deleting the destination first, so
      co-located files owned by other overlays (sheen, Adhesion, etc.) are
      never touched. Every file this function writes is appended to
      $TrackedPaths (repo-root-relative, forward-slash normalized) so the
      caller can later prune only the files BaseCoat itself previously
      placed and no longer manages.
    #>
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DestDir,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$TrackedPaths
    )

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        return
    }

    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    $sourceFullPath = (Resolve-Path -LiteralPath $SourceDir).Path
    # Canonicalize the destination root itself once; every per-file
    # containment check below is relative to this resolved boundary.
    $destRootCanonical = Get-CanonicalRealPath -Path $DestDir

    Get-ChildItem -LiteralPath $SourceDir -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($sourceFullPath.Length).TrimStart('\', '/')
        $destFile = Join-Path $DestDir $relative
        $destFileDir = Split-Path -Parent $destFile
        New-Item -ItemType Directory -Force -Path $destFileDir | Out-Null

        if (-not (Test-PathWithinBoundary -Path $destFileDir -BoundaryRoot $destRootCanonical)) {
            Write-Warning "Refusing to write through a symlinked overlay path outside '$DestDir': $destFile"
            return
        }
        if (Test-Path -LiteralPath $destFile) {
            $existingLeaf = Get-Item -LiteralPath $destFile -Force
            if ($null -ne $existingLeaf.ResolveLinkTarget($false)) {
                Write-Warning "Refusing to overwrite a symlinked overlay destination file: $destFile"
                return
            }
        }

        Copy-Item -LiteralPath $_.FullName -Destination $destFile -Force
        $TrackedPaths.Add((Get-RepoRelativePath -Path $destFile -RepoRoot $RepoRoot))
    }
}

function Remove-EmptyOverlayParents {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$StopAt
    )

    $dir = Split-Path -Path $Path -Parent
    while ($dir -and (Test-Path -LiteralPath $dir) -and ($StopAt -notcontains $dir)) {
        $hasChildren = (Get-ChildItem -LiteralPath $dir -Force | Measure-Object).Count -gt 0
        if ($hasChildren) { break }
        Remove-Item -LiteralPath $dir -Force
        $dir = Split-Path -Path $dir -Parent
    }
}

$sourcePathOverride = $env:BASECOAT_TEST_SOURCE_PATH
$tempRoot = $null
$sourcePath = $null
$guidanceStage = $null

try {
    if ($sourcePathOverride) {
        $sourcePath = (Resolve-Path -LiteralPath $sourcePathOverride).Path
        Write-Host "Using pre-materialized BaseCoat source at '$sourcePath'"
    }
    else {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $sourcePath = Join-Path $tempRoot 'source'
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        if ($sourceRef -match '^[0-9a-fA-F]{40}$') {
            $null = Invoke-SyncGit -Arguments @('init', $sourcePath)
            $null = Invoke-SyncGit -Arguments @('-C', $sourcePath, 'remote', 'add', 'origin', $fetchRepo)
            $null = Invoke-SyncGitWithAuthRetry -Arguments @(
                '-C', $sourcePath, 'fetch', '--depth', '1', 'origin', $sourceRef
            ) -RepoUrl $fetchRepo
            $null = Invoke-SyncGit -Arguments @('-C', $sourcePath, 'checkout', '--detach', 'FETCH_HEAD')
        }
        else {
            $null = Invoke-SyncGitWithAuthRetry -Arguments @(
                'clone', '--depth', '1', '--branch', $sourceRef, $fetchRepo, $sourcePath
            ) -RepoUrl $fetchRepo
        }
    }
    $sourceCommit = ((Invoke-SyncGit -Arguments @('-C', $sourcePath, 'rev-parse', 'HEAD')) -join "`n").Trim()
    if ($env:BASECOAT_EXPECTED_SHA -and $sourceCommit -ne $env:BASECOAT_EXPECTED_SHA) {
        throw "BaseCoat source provenance check failed: expected commit '$($env:BASECOAT_EXPECTED_SHA)' but fetched '$sourceCommit'."
    }

    $fullTargetDir = Join-Path $repoRoot $targetDir
    New-Item -ItemType Directory -Force -Path $fullTargetDir | Out-Null

    # Capture the PREVIOUS release's asset-manifest.json before it is
    # overwritten below. If this repo has never run the #3415-fixed sync
    # before (no guidance lock or legacy tracker yet), this lets that first
    # sync still identify and prune shared-overlay files the OLD
    # wholesale-wipe sync previously installed but this new release retires
    # — otherwise they would linger in the overlay forever.
    $previousAssetManifestPath = Join-Path $fullTargetDir 'asset-manifest.json'
    $previousAssetManifest = $null
    if (Test-Path -LiteralPath $previousAssetManifestPath) {
        try {
            $previousAssetManifest = Get-Content -LiteralPath $previousAssetManifestPath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "Ignoring unreadable previous asset manifest '$previousAssetManifestPath': $($_.Exception.Message)"
        }
    }

    foreach ($item in @('README.md', 'CHANGELOG.md', 'version.json', 'asset-manifest.json', 'instructions', 'skills', 'prompts', 'agents', 'templates', 'schemas')) {
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
            'validate-skill-visibility.ps1',
            'validate-asset-distribution.ps1',
            'validate-workflow-action-pins.ps1',
            'validate-workflow-action-pins.py',
            'workflow-ownership.ps1',
            'retire-downstream-workflows.ps1',
            'guidance-lock.ps1',
            'guidance-lock.sh'
        )) {
        $validatorSource = Join-Path $sourcePath "scripts/$validator"
        if (Test-Path $validatorSource -PathType Leaf) {
            Copy-Item -Path $validatorSource -Destination (Join-Path $runtimeScriptsDest $validator) -Force
        }
    }
    $canonicalContractRoot = Join-Path $repoRoot '.github/base-coat'
    New-Item -ItemType Directory -Path (Join-Path $canonicalContractRoot 'scripts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $canonicalContractRoot 'schemas') -Force | Out-Null
    foreach ($helperName in @('guidance-lock.ps1', 'guidance-lock.sh')) {
        $helperSource = Join-Path $sourcePath "scripts/$helperName"
        if (Test-Path -LiteralPath $helperSource -PathType Leaf) {
            Copy-Item -LiteralPath $helperSource -Destination (Join-Path $canonicalContractRoot "scripts/$helperName") -Force
        }
    }
    $guidanceSchemaSource = Join-Path $sourcePath 'schemas/guidance-lock-v1.schema.json'
    if (Test-Path -LiteralPath $guidanceSchemaSource -PathType Leaf) {
        Copy-Item -LiteralPath $guidanceSchemaSource `
            -Destination (Join-Path $canonicalContractRoot 'schemas/guidance-lock-v1.schema.json') -Force
    }

    [ordered]@{
        schemaVersion = 1
        commit = $sourceCommit
        requestedRef = $sourceRef
        source = Get-RedactedRepoUrl $sourceRepo
        mirror = Get-RedactedRepoUrl $sourceMirror
    } | ConvertTo-Json | Set-Content -Path (Join-Path $fullTargetDir '.source-provenance.json') -Encoding UTF8

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

    # Shared physical destinations use one cross-product ownership source.
    # Build and preflight the complete plan before changing any shared file.
    $guidanceHelper = @(
        (Join-Path $sourcePath 'scripts/guidance-lock.ps1'),
        (Join-Path $PSScriptRoot 'scripts/guidance-lock.ps1'),
        (Join-Path $repoRoot '.github/base-coat/scripts/guidance-lock.ps1')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $guidanceHelper) {
        throw "GUIDANCE_LOCK_INVALID reason='source payload is missing scripts/guidance-lock.ps1'"
    }
    . $guidanceHelper

    $legacyOverlayStatePath = Join-Path $fullTargetDir '.overlay-managed-files'
    $legacyOverlayFiles = @()
    if (Test-Path -LiteralPath $legacyOverlayStatePath -PathType Leaf) {
        $legacyOverlayFiles = @(
            Get-Content -LiteralPath $legacyOverlayStatePath |
                ForEach-Object { $_.TrimEnd("`r") } |
                Where-Object { $_ -ne '' }
        )
    }
    elseif ($previousAssetManifest -and $previousAssetManifest.assets -and
        -not (Test-Path -LiteralPath (Get-GuidanceLockPath -RepoRoot $repoRoot) -PathType Leaf)) {
        $seeded = [System.Collections.Generic.List[string]]::new()
        foreach ($asset in $previousAssetManifest.assets) {
            if (-not $asset.path) { continue }
            $assetPath = ($asset.path -replace '\\', '/')
            $candidateDests = @()
            if ($assetPath -match '^agents/references/(.+)$') {
                $candidateDests += ".github/agents/references/$($Matches[1])"
            }
            elseif ($assetPath -match '^agents/([^/]+\.agent\.md)$') {
                $candidateDests += ".github/agents/$($Matches[1])"
            }
            elseif ($assetPath -match '^instructions/(.+)$') {
                $candidateDests += ".github/instructions/$($Matches[1])"
            }
            elseif ($assetPath -match '^prompts/(.+)$') {
                $candidateDests += ".github/prompts/$($Matches[1])"
            }
            elseif ($assetPath -match '^skills/(.+)$') {
                $candidateDests += ".github/skills/$($Matches[1])"
                $candidateDests += ".agents/skills/$($Matches[1])"
            }
            foreach ($candidate in $candidateDests) {
                if (Test-Path -LiteralPath (Join-Path $repoRoot $candidate) -PathType Leaf) {
                    $seeded.Add($candidate)
                }
            }
        }
        $legacyOverlayFiles = @($seeded | Sort-Object -Unique)
    }

    $sourceVersion = [string](Get-Content -LiteralPath (Join-Path $fullTargetDir 'version.json') -Raw | ConvertFrom-Json).version
    $guidanceStage = Join-Path $fullTargetDir ".guidance-overlay-stage-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $guidanceStage -Force | Out-Null
    $guidancePlan = [System.Collections.Generic.List[object]]::new()
    $plannedPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    function Add-GuidancePlanTree {
        param(
            [Parameter(Mandatory)][string]$SourceDir,
            [Parameter(Mandatory)][string]$DestinationPrefix,
            [Parameter(Mandatory)][string]$GuidanceUnitPrefix
        )
        if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) { return }
        $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
        Get-ChildItem -LiteralPath $SourceDir -Recurse -File | ForEach-Object {
            $relative = $_.FullName.Substring($sourceRoot.Length).TrimStart('\', '/') -replace '\\', '/'
            $destination = Normalize-GuidancePath -Path "$DestinationPrefix/$relative" -RepoRoot $repoRoot
            if (-not $plannedPaths.Add($destination)) {
                throw "GUIDANCE_LOCK_INVALID path='$destination' reason='duplicate path in BaseCoat write plan'"
            }
            $guidancePlan.Add([pscustomobject]@{
                path = $destination
                source = $_.FullName
                entry = New-GuidanceLockEntry -RepoRoot $repoRoot -Path $destination -Owner 'basecoat' `
                    -GuidanceUnit "$GuidanceUnitPrefix/$relative" -SourceVersion $sourceVersion `
                    -Sha256 (Get-GuidanceContentHash -Path $_.FullName)
            })
        }
    }

    foreach ($copilotDir in @('instructions', 'prompts', 'skills')) {
        Add-GuidancePlanTree -SourceDir (Join-Path $fullTargetDir $copilotDir) `
            -DestinationPrefix ".github/$copilotDir" -GuidanceUnitPrefix $copilotDir
    }
    Add-GuidancePlanTree -SourceDir (Join-Path $fullTargetDir 'skills') `
        -DestinationPrefix '.agents/skills' -GuidanceUnitPrefix 'skills'

    $agentSource = Join-Path $fullTargetDir 'agents'
    if (Test-Path -LiteralPath $agentSource -PathType Container) {
        Get-ChildItem -LiteralPath $agentSource -Filter '*.agent.md' -File | ForEach-Object {
            $stagedAgent = Join-Path $guidanceStage $_.Name
            $sanitized = Convert-AgentToCliCompatibleContent -Content (Get-Content -LiteralPath $_.FullName -Raw)
            Set-Content -LiteralPath $stagedAgent -Value $sanitized -Encoding UTF8
            $destination = Normalize-GuidancePath -Path ".github/agents/$($_.Name)" -RepoRoot $repoRoot
            if (-not $plannedPaths.Add($destination)) {
                throw "GUIDANCE_LOCK_INVALID path='$destination' reason='duplicate path in BaseCoat write plan'"
            }
            $guidancePlan.Add([pscustomobject]@{
                path = $destination
                source = $stagedAgent
                entry = New-GuidanceLockEntry -RepoRoot $repoRoot -Path $destination -Owner 'basecoat' `
                    -GuidanceUnit "agents/$($_.Name)" -SourceVersion $sourceVersion `
                    -Sha256 (Get-GuidanceContentHash -Path $stagedAgent)
            })
        }
    }
    Add-GuidancePlanTree -SourceDir (Join-Path $agentSource 'references') `
        -DestinationPrefix '.github/agents/references' -GuidanceUnitPrefix 'agents/references'

    $guidanceLockPath = Get-GuidanceLockPath -RepoRoot $repoRoot
    $guidanceLock = Read-GuidanceLock -RepoRoot $repoRoot -LockPath $guidanceLockPath
    $lockEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($guidanceLock.entries)) { $lockEntries.Add($entry) }

    if (-not (Test-Path -LiteralPath $guidanceLockPath -PathType Leaf)) {
        foreach ($legacyPath in $legacyOverlayFiles) {
            $normalizedLegacyPath = Normalize-GuidancePath -Path $legacyPath -RepoRoot $repoRoot
            $legacyFullPath = Join-Path $repoRoot $normalizedLegacyPath
            if (Test-Path -LiteralPath $legacyFullPath -PathType Leaf) {
                $lockEntries.Add((New-GuidanceLockEntry -RepoRoot $repoRoot -Path $normalizedLegacyPath `
                    -Owner 'basecoat' -GuidanceUnit 'legacy-overlay-migration' -SourceVersion $sourceVersion `
                    -Sha256 (Get-GuidanceContentHash -Path $legacyFullPath)))
            }
        }
        if ($legacyOverlayFiles.Count -gt 0) {
            Write-Host "Migrating $($legacyOverlayFiles.Count) legacy overlay ownership record(s) to guidance-lock/v1."
        }
    }

    $lockByPath = @{}
    foreach ($entry in $lockEntries) {
        if ($lockByPath.ContainsKey($entry.path)) {
            throw "GUIDANCE_LOCK_INVALID path='$($entry.path)' reason='duplicate path entry after migration'"
        }
        $lockByPath[$entry.path] = $entry
    }

    $repoRootCanonical = Get-CanonicalRealPath -Path $repoRoot
    foreach ($planned in $guidancePlan) {
        $destination = Join-Path $repoRoot $planned.path
        if (-not (Test-PathWithinBoundary -Path (Split-Path -Parent $destination) -BoundaryRoot $repoRootCanonical)) {
            throw "GUIDANCE_LOCK_INVALID path='$($planned.path)' reason='destination resolves outside the repository root'"
        }
        if (Test-Path -LiteralPath $destination) {
            $leaf = Get-Item -LiteralPath $destination -Force
            if ($null -ne $leaf.ResolveLinkTarget($false)) {
                throw "GUIDANCE_PATH_COLLISION path='$($planned.path)' owner='symlink' claimant='basecoat'"
            }
            if (-not $leaf.PSIsContainer -and -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
                throw "GUIDANCE_PATH_COLLISION path='$($planned.path)' owner='invalid-destination' claimant='basecoat'"
            }
            if ($leaf.PSIsContainer) {
                throw "GUIDANCE_PATH_COLLISION path='$($planned.path)' owner='directory' claimant='basecoat'"
            }
        }
        $existingEntry = $lockByPath[$planned.path]
        if ($existingEntry) {
            if ($existingEntry.owner -ne 'basecoat') {
                throw "GUIDANCE_PATH_COLLISION path='$($planned.path)' owner='$($existingEntry.owner)' claimant='basecoat'"
            }
            if (Test-Path -LiteralPath $destination -PathType Leaf) {
                $actualHash = Get-GuidanceContentHash -Path $destination
                if ($actualHash -ne $existingEntry.sha256) {
                    throw "GUIDANCE_CONTENT_MODIFIED path='$($planned.path)' owner='basecoat' expected='$($existingEntry.sha256)' actual='$actualHash'"
                }
            }
        }
        elseif (Test-Path -LiteralPath $destination) {
            throw "GUIDANCE_PATH_COLLISION path='$($planned.path)' owner='unmanaged' claimant='basecoat'"
        }
    }

    $overlayStopDirs = @(
        (Join-Path $repoRoot '.github/instructions'),
        (Join-Path $repoRoot '.github/prompts'),
        (Join-Path $repoRoot '.github/skills'),
        (Join-Path $repoRoot '.github/agents'),
        (Join-Path $repoRoot '.agents/skills')
    )
    $staleBasecoatEntries = @($lockEntries | Where-Object {
        $_.owner -eq 'basecoat' -and -not $plannedPaths.Contains($_.path)
    })
    foreach ($staleEntry in $staleBasecoatEntries) {
        $staleFull = Join-Path $repoRoot $staleEntry.path
        if (Test-Path -LiteralPath $staleFull -PathType Leaf) {
            if (-not (Test-PathWithinBoundary -Path $staleFull -BoundaryRoot $repoRootCanonical)) {
                throw "GUIDANCE_LOCK_INVALID path='$($staleEntry.path)' reason='stale destination resolves outside the repository root'"
            }
            $actualHash = Get-GuidanceContentHash -Path $staleFull
            if ($actualHash -ne $staleEntry.sha256) {
                throw "GUIDANCE_CONTENT_MODIFIED path='$($staleEntry.path)' owner='basecoat' expected='$($staleEntry.sha256)' actual='$actualHash'"
            }
        }
    }

    foreach ($planned in $guidancePlan) {
        $destination = Join-Path $repoRoot $planned.path
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $planned.source -Destination $destination -Force
    }
    foreach ($staleEntry in $staleBasecoatEntries) {
        $staleFull = Join-Path $repoRoot $staleEntry.path
        if (Test-Path -LiteralPath $staleFull -PathType Leaf) {
            Remove-Item -LiteralPath $staleFull -Force
            Remove-EmptyOverlayParents -Path $staleFull -StopAt $overlayStopDirs
            Write-Host "Removed stale BaseCoat-managed guidance file: $($staleEntry.path)"
        }
    }

    $nextEntries = @(
        $lockEntries | Where-Object { $_.owner -ne 'basecoat' }
        $guidancePlan | ForEach-Object { $_.entry }
    )
    Write-GuidanceLock -RepoRoot $repoRoot -LockPath $guidanceLockPath -Entries $nextEntries
    @(
        $legacyOverlayStatePath,
        (Join-Path $repoRoot '.github/base-coat/.overlay-managed-files')
    ) | Sort-Object -Unique | ForEach-Object {
        Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue
    }

    Remove-Item -LiteralPath $guidanceStage -Recurse -Force -ErrorAction SilentlyContinue

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
    if ($guidanceStage -and (Test-Path -LiteralPath $guidanceStage)) {
        Remove-Item -LiteralPath $guidanceStage -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        try {
            Remove-PathWithRetry -Path $tempRoot
        }
        catch {
            Write-Warning "Cleanup warning: $($_.Exception.Message)"
        }
    }
}

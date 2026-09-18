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
    # before (no .overlay-managed-files state yet), this lets that first
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
            'validate-skill-visibility.ps1',
            'validate-asset-distribution.ps1',
            'validate-workflow-action-pins.ps1',
            'validate-workflow-action-pins.py',
            'workflow-ownership.ps1',
            'retire-downstream-workflows.ps1'
        )) {
        $validatorSource = Join-Path $sourcePath "scripts/$validator"
        if (Test-Path $validatorSource -PathType Leaf) {
            Copy-Item -Path $validatorSource -Destination (Join-Path $runtimeScriptsDest $validator) -Force
        }
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

    # Copy Copilot-discoverable directories to their standard paths.
    # Only copy flat agent/instruction/prompt/skill files — not taxonomy subdirs.
    #
    # These shared paths (.github/instructions, .github/prompts, .github/skills,
    # .github/agents, .github/agents/references, .agents/skills) can also be
    # written to by other overlays (e.g. basecoat-sheen, basecoat-adhesion), so
    # BaseCoat must never wipe the destination directory wholesale — that would
    # silently delete co-located files it does not own (#3415). Instead, copy
    # files individually (never deleting anything first) and track every path
    # BaseCoat writes in $overlayManagedFiles. After all copies, prune only the
    # files BaseCoat itself previously placed (per the prior sync's tracked
    # list) that are no longer part of this sync — every other file, whether
    # foreign or simply untracked, is left untouched.
    # This state file uses the same plain-text, newline-separated, sorted
    # format and filename as sync.sh's overlay tracking so a consumer repo
    # that alternates between sync.ps1 (e.g. local Windows dev) and sync.sh
    # (e.g. Linux CI) shares one consistent ownership record instead of each
    # script only ever seeing its own history.
    $overlayStatePath = Join-Path $fullTargetDir '.overlay-managed-files'
    $overlayStateExisted = Test-Path -LiteralPath $overlayStatePath
    $prevOverlayFiles = @()
    if ($overlayStateExisted) {
        try {
            $prevOverlayFiles = @(
                Get-Content -LiteralPath $overlayStatePath |
                    ForEach-Object { $_.TrimEnd("`r") } |
                    Where-Object { $_ -ne '' }
            )
        }
        catch {
            Write-Warning "Ignoring unreadable overlay state file '$overlayStatePath': $($_.Exception.Message)"
        }
    }
    elseif ($previousAssetManifest -and $previousAssetManifest.assets) {
        # First sync after upgrading to the #3415 fix: there is no tracked
        # ownership history yet, but the OLD wholesale-wipe sync logic may
        # have installed files this new release retires. Reconstruct where
        # each previously-distributed asset would have landed and, if it
        # still exists on disk, treat it as BaseCoat-managed so it can be
        # correctly identified as stale below instead of lingering forever.
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
        if ($seeded.Count -gt 0) {
            Write-Host "Seeding overlay ownership from $($seeded.Count) previously-distributed file(s) for first sync after #3415 fix."
            $prevOverlayFiles = @($seeded | Sort-Object -Unique)
        }
    }
    $overlayManagedFiles = [System.Collections.Generic.List[string]]::new()

    $githubDir = Join-Path $repoRoot '.github'
    New-Item -ItemType Directory -Force -Path $githubDir | Out-Null
    foreach ($copilotDir in @('instructions', 'prompts', 'skills')) {
        $source = Join-Path $fullTargetDir $copilotDir
        $dest = Join-Path $githubDir $copilotDir
        Copy-ManagedOverlayTree -SourceDir $source -DestDir $dest -RepoRoot $repoRoot -TrackedPaths $overlayManagedFiles
    }

    # Also copy skills to .agents/skills/ for cross-client interop (Agent Skills spec)
    $skillsSource = Join-Path $fullTargetDir 'skills'
    $agentSkillsDest = Join-Path $repoRoot '.agents' 'skills'
    Copy-ManagedOverlayTree -SourceDir $skillsSource -DestDir $agentSkillsDest -RepoRoot $repoRoot -TrackedPaths $overlayManagedFiles

    # Agents: copy only *.agent.md files (skip taxonomy subdirs like models/, tasks/, types/)
    $agentSource = Join-Path $fullTargetDir 'agents'
    $agentDest = Join-Path $githubDir 'agents'
    if (Test-Path $agentSource) {
        New-Item -ItemType Directory -Force -Path $agentDest | Out-Null
        $githubDirCanonical = Get-CanonicalRealPath -Path $githubDir
        Get-ChildItem -Path $agentSource -Filter '*.agent.md' | ForEach-Object {
            $destFile = Join-Path $agentDest $_.Name
            if (-not (Test-PathWithinBoundary -Path $agentDest -BoundaryRoot $githubDirCanonical)) {
                Write-Warning "Refusing to write through a symlinked overlay path outside '$githubDir': $destFile"
                return
            }
            if (Test-Path -LiteralPath $destFile) {
                $existingLeaf = Get-Item -LiteralPath $destFile -Force
                if ($null -ne $existingLeaf.ResolveLinkTarget($false)) {
                    Write-Warning "Refusing to overwrite a symlinked overlay destination file: $destFile"
                    return
                }
            }
            $raw = Get-Content -Path $_.FullName -Raw
            $sanitized = Convert-AgentToCliCompatibleContent -Content $raw
            Set-Content -Path $destFile -Value $sanitized -Encoding UTF8
            $overlayManagedFiles.Add((Get-RepoRelativePath -Path $destFile -RepoRoot $repoRoot))
        }
    }

    # Agent references: agent files may link to agents/references/<name>-detail.md
    # for overflow content moved out to satisfy the token budget. Copy the whole
    # subtree so those relative links resolve for installed agents.
    $agentReferencesSource = Join-Path $agentSource 'references'
    $agentReferencesDest = Join-Path $agentDest 'references'
    Copy-ManagedOverlayTree -SourceDir $agentReferencesSource -DestDir $agentReferencesDest -RepoRoot $repoRoot -TrackedPaths $overlayManagedFiles

    # Prune only files BaseCoat previously placed in the shared overlay
    # directories that are no longer part of the current sync. Anything not
    # in $prevOverlayFiles (foreign files, or files never tracked) is left
    # alone, regardless of whether it happens to sit in one of these dirs.
    $overlayStopDirs = @(
        (Join-Path $githubDir 'instructions'),
        (Join-Path $githubDir 'prompts'),
        (Join-Path $githubDir 'skills'),
        (Join-Path $githubDir 'agents'),
        $agentSkillsDest
    )
    # Deletion candidates come from a state file (or, for the first sync,
    # the reconstructed previous manifest) that could in principle contain a
    # corrupted or maliciously crafted entry (e.g. '../victim' or a path
    # under .github/workflows). Reject anything that is not a relative path
    # confined to one of the exact managed overlay prefixes before it is
    # even joined to $repoRoot, then re-verify containment against the
    # canonical (symlink-resolved) boundary right before deleting.
    $allowedOverlayPrefixes = @(
        '.github/instructions/', '.github/prompts/', '.github/skills/',
        '.github/agents/', '.agents/skills/'
    )
    $repoRootCanonical = Get-CanonicalRealPath -Path $repoRoot
    $staleOverlayFiles = $prevOverlayFiles | Where-Object { $overlayManagedFiles -notcontains $_ }
    foreach ($staleRel in $staleOverlayFiles) {
        $normalizedStaleRel = ($staleRel -replace '\\', '/')
        $isRooted = $normalizedStaleRel.StartsWith('/') -or [System.IO.Path]::IsPathRooted($normalizedStaleRel)
        $hasTraversal = $normalizedStaleRel -match '(^|/)\.\.(/|$)'
        $hasAllowedPrefix = $false
        foreach ($prefix in $allowedOverlayPrefixes) {
            if ($normalizedStaleRel.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                $hasAllowedPrefix = $true
                break
            }
        }
        if ($isRooted -or $hasTraversal -or -not $hasAllowedPrefix) {
            Write-Warning "Skipping stale overlay entry outside the managed overlay prefixes: $staleRel"
            continue
        }

        $staleFull = Join-Path $repoRoot $normalizedStaleRel
        if (Test-Path -LiteralPath $staleFull -PathType Leaf) {
            if (-not (Test-PathWithinBoundary -Path $staleFull -BoundaryRoot $repoRootCanonical)) {
                Write-Warning "Refusing to delete a stale overlay entry that resolves outside the repository: $staleRel"
                continue
            }
            Remove-Item -LiteralPath $staleFull -Force
            Remove-EmptyOverlayParents -Path $staleFull -StopAt $overlayStopDirs
            Write-Host "Removed stale BaseCoat-managed overlay file: $staleRel"
        }
    }

    # Force LF line endings (not the platform default) so this file stays
    # byte-compatible with sync.sh's plain `comm`/`sort`-based reader.
    $sortedOverlayFiles = @($overlayManagedFiles | Sort-Object -Unique)
    $overlayStateContent = if ($sortedOverlayFiles.Count -gt 0) { ($sortedOverlayFiles -join "`n") + "`n" } else { '' }
    [System.IO.File]::WriteAllText($overlayStatePath, $overlayStateContent, [System.Text.UTF8Encoding]::new($false))

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
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        try {
            Remove-PathWithRetry -Path $tempRoot
        }
        catch {
            Write-Warning "Cleanup warning: $($_.Exception.Message)"
        }
    }
}
